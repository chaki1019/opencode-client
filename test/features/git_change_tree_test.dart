import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/project_tools.dart';
import 'package:opencode_mobile/features/git/change_tree.dart';

void main() {
  test('groups files by folder and merges single-folder chains', () {
    final root = buildChangeTree(const [
      FileChange(file: 'README.md'),
      FileChange(file: 'lib/features/git/git_screen.dart'),
      FileChange(file: 'lib/features/git/change_tree.dart'),
      FileChange(file: 'lib/app/router.dart'),
      FileChange(file: 'test/widget_test.dart'),
    ]);

    expect(root.files.map((f) => f.file), ['README.md']);
    expect(root.folders.map((f) => f.name), ['lib', 'test']);
    final lib = root.folders.first;
    expect(lib.folders.map((f) => f.name), ['app', 'features/git']);
    final git = lib.folders.last;
    expect(git.path, 'lib/features/git');
    expect(git.files.map((f) => f.file), [
      'lib/features/git/change_tree.dart',
      'lib/features/git/git_screen.dart',
    ]);
  });
}
