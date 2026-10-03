import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/features/projects/server_path.dart';

void main() {
  test('walks POSIX paths', () {
    expect(ServerPath.join('/home/me', 'src/'), '/home/me/src');
    expect(ServerPath.join('/', 'home/'), '/home');
    expect(ServerPath.parent('/home/me'), '/home');
    expect(ServerPath.parent('/home'), '/');
    expect(ServerPath.parent('/'), isNull);
    expect(ServerPath.crumbs('/home/me'), [
      ('/', '/'),
      ('home', '/home'),
      ('me', '/home/me'),
    ]);
  });

  test('walks Windows paths', () {
    expect(ServerPath.join(r'C:\Users', r'me\'), r'C:\Users\me');
    expect(ServerPath.parent(r'C:\Users\me'), r'C:\Users');
    expect(ServerPath.parent(r'C:\Users'), r'C:\');
    expect(ServerPath.parent(r'C:\'), isNull);
    expect(ServerPath.name(r'C:\Users\me'), 'me');
  });

  test('normalizes typed paths', () {
    expect(ServerPath.normalize(' /srv/app/ '), '/srv/app');
    expect(ServerPath.normalize('/'), '/');
    expect(ServerPath.isAbsolute('/srv'), isTrue);
    expect(ServerPath.isAbsolute(r'D:\work'), isTrue);
    expect(ServerPath.isAbsolute('srv/app'), isFalse);
  });
}
