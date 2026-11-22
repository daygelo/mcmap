/// Audience preference. The backend must authorize access independently.
enum StudentVisibility {
  private('Private'),
  friends('Friends'),
  public('Public');

  const StudentVisibility(this.label);

  final String label;
}
