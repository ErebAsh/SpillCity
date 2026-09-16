import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<AuthResponse> execute(String email, String password) {
    return repository.signIn(email: email, password: password);
  }
}
