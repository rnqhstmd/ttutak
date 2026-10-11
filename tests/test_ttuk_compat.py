"""Migration contracts and release safety, using disposable fixture manifests."""
import fnmatch
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReleaseFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'tools').mkdir()
        shutil.copy2(ROOT / 'tools/bump-version.sh', self.root / 'tools/bump-version.sh')
        self.paths = ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', '.codex-plugin/plugin.json']
        data = [{'name': 'ttuk-ttak', 'version': '2.0.0'}, {'plugins': [{'name': 'ttuk-ttak', 'version': '2.0.0'}, {'name': 'other', 'version': '1.0.0'}]}, {'name': 'ttuk-ttak', 'version': '2.0.0'}]
        for path, obj in zip(self.paths, data):
            target = self.root / path
            target.parent.mkdir(exist_ok=True)
            target.write_text(json.dumps(obj) + '\n')
        (self.root / 'CHANGELOG.md').write_text('## v2.1.00\nwrong\n')

    def run_bump(self, version='2.1.0', env=None):
        return subprocess.run(['bash', str(self.root / 'tools/bump-version.sh'), version], capture_output=True, text=True, env=env)

    def snapshot(self):
        return [(self.root / p).read_bytes() for p in self.paths]



class ReleaseCompatibility(ReleaseFixture):
    def test_updates_three_manifests_and_preserves_other_plugin(self):
        result = self.run_bump()
        self.assertEqual(result.returncode, 0, result.stderr)
        objects = [json.loads((self.root / p).read_text()) for p in self.paths]
        self.assertEqual(objects[0]['version'], '2.1.0')
        self.assertEqual(objects[1]['plugins'][0]['version'], '2.1.0')
        self.assertEqual(objects[1]['plugins'][1]['version'], '1.0.0')
        self.assertEqual(objects[2]['version'], '2.1.0')
        self.assertIn('WARNING:', result.stderr)  # v2.1.00 cannot satisfy v2.1.0
        self.assertFalse(list(self.root.rglob('*.bak')))
        self.assertFalse(list(self.root.rglob('*.tmp')))

    def test_rejects_name_mismatch_before_writes(self):
        (self.root / self.paths[2]).write_text('{"name":"other","version":"2.0.0"}\n')
        before = self.snapshot()
        self.assertNotEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_rejects_duplicate_marketplace_entries(self):
        (self.root / self.paths[1]).write_text('{"plugins":[{"name":"ttuk-ttak"},{"name":"ttuk-ttak"}]}\n')
        before = self.snapshot()
        self.assertNotEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_rejects_invalid_semver_before_writes(self):
        before = self.snapshot()
        for version in ('', '01.2.3', '2.1.0suffix', '2x1x0'):
            self.assertNotEqual(self.run_bump(version).returncode, 0)
            self.assertEqual(self.snapshot(), before)

    def test_failed_second_move_rolls_back_all_files(self):
        bindir = self.root / 'bin'
        bindir.mkdir()
        wrapper = bindir / 'mv'
        actual_mv = shutil.which('mv')
        wrapper.write_text('#!/bin/bash\ncase "$1" in */marketplace.json.tmp) exit 44 ;; esac\nexec ' + actual_mv + ' "$@"\n')
        wrapper.chmod(0o755)
        env = dict(os.environ, PATH=str(bindir) + os.pathsep + os.environ['PATH'])
        before = self.snapshot()
        result = self.run_bump(env=env)
        self.assertEqual(result.returncode, 44, result.stderr)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(list(self.root.rglob('*.bak')))
        self.assertFalse(list(self.root.rglob('*.tmp')))

    def test_rejects_existing_backup_without_deleting_it(self):
        backup = self.root / (self.paths[0] + '.bak')
        backup.write_text('recoverable copy')
        before = self.snapshot()
        self.assertNotEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(backup.read_text(), 'recoverable copy')

    def test_malformed_json_leaves_manifests_unchanged(self):
        (self.root / self.paths[1]).write_text('{broken')
        before = self.snapshot()
        self.assertNotEqual(self.run_bump().returncode, 0)
        self.assertEqual(self.snapshot(), before)


class ReleaseWorkflow(ReleaseFixture):
    def workflow_run(self, step_name, **extra_env):
        workflow = (ROOT / '.github/workflows/release.yml').read_text()
        section = workflow.split('      - name: ' + step_name, 1)[1].split('      - name:', 1)[0]
        script = section.split('        run: |\n', 1)[1]
        script = '\n'.join(line[10:] if line.startswith('          ') else line for line in script.splitlines())
        output = self.root / 'github-output'
        env = dict(os.environ, GITHUB_OUTPUT=str(output), RUNNER_TEMP=str(self.root), **extra_env)
        return subprocess.run(['bash', '-c', script], cwd=self.root, env=env, text=True, capture_output=True)

    def test_workflow_rejects_codex_version_drift(self):
        (self.root / 'CHANGELOG.md').write_text('## v2.0.0\nrelease\n')
        (self.root / self.paths[2]).write_text('{"name":"ttuk-ttak","version":"1.9.0"}')
        result = self.workflow_run('Verify manifest parity and changelog')
        self.assertNotEqual(result.returncode, 0)

    def test_workflow_rejects_substring_changelog(self):
        (self.root / 'CHANGELOG.md').write_text('## v2.0.00\nwrong\n')
        self.assertNotEqual(self.workflow_run('Verify manifest parity and changelog').returncode, 0)

    def test_workflow_extracts_final_section_without_losing_last_line(self):
        (self.root / 'CHANGELOG.md').write_text('## v2.1.00\nwrong\n## v2.1.0 — Release\nfirst\nlast\n')
        result = self.workflow_run('Extract changelog for this version', VERSION='2.1.0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'release_body.md').read_text(), 'first\nlast\n')
        self.assertIn('title=v2.1.0 — Release', (self.root / 'github-output').read_text())


class MigrationConfig(unittest.TestCase):
    def test_concrete_sensitive_patterns_preserve_normal_source_names(self):
        config = json.loads((ROOT / '.claude/config.json').read_text())
        patterns = config['sensitiveFilePatterns']
        for filename in ('secret-service.ts', 'credentials-helper.py', '.environment.ts'):
            self.assertFalse(any(fnmatch.fnmatch(filename, p) for p in patterns), filename)
        for filename in ('.env', '.env.production', 'id_rsa', 'credentials.json', 'private.pem'):
            self.assertTrue(any(fnmatch.fnmatch(filename, p) for p in patterns), filename)
        self.assertEqual(config['notifications']['slack'], {'enabled': False, 'webhookUrl': ''})
        self.assertIn('test', config['projectTypes']['node'])
        self.assertIn('focusedTest', config['projectTypes']['java-spring'])
        self.assertIn('reviewer', config['contextLimits'])
        self.assertIn('modelProfile', config)

    def test_setup_template_preserves_slack_and_upstream_fields(self):
        source = json.loads((ROOT / '.claude/config.json').read_text())
        template = json.loads((ROOT / '.claude/skills/setup/references/config.template.json').read_text())
        self.assertEqual(source, template)


if __name__ == '__main__':
    unittest.main()
