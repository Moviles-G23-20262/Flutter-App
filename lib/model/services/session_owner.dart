/// Who is signed in, for the parts of the model that keep per-user copies on the phone.
/// Set by the auth repository when a session starts or ends.
class SessionOwner {
  String? _userId;

  String? get userId => _userId;

  void signedIn(String userId) => _userId = userId;

  void signedOut() => _userId = null;
}
