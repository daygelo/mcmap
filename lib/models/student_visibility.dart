/// Audience preference. The backend must authorize access independently.
enum StudentVisibility {
  private('Private'),
  friends('Friends'),
  public('Public');

  const StudentVisibility(this.label);

  /// New RSVPs are public unless the student chooses otherwise.
  static const defaultForRsvps = public;

  final String label;
}
