import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../backend/mcmap_backend.dart';
import '../models/club_event.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({
    super.key,
    required this.backend,
    required this.groups,
    required this.onPublished,
  });

  final McMapBackend backend;
  final List<PublishingGroup> groups;
  final ValueChanged<ClubEvent> onPublished;

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _form = GlobalKey<FormState>();
  int _formGeneration = 0;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _publicationIds = <String, String>{};
  late String? _groupId = _initialGroup;
  DateTime? _start;
  DateTime? _end;
  bool _publishing = false;
  String? _error;

  String? get _initialGroup =>
      widget.groups.length == 1 ? widget.groups.single.id : null;

  @override
  void didUpdateWidget(CreateEventPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.groups.any((group) => group.id == _groupId)) {
      _groupId = _initialGroup;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(
    FormFieldState<DateTime> field, {
    required bool end,
  }) async {
    final now = DateTime.now();
    final initial = field.value ?? _start ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (date == null || !mounted || !field.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted || !field.mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (value.hour != time.hour || value.minute != time.minute) {
      setState(
        () => _error = 'This time does not exist in your local time zone.',
      );
      return;
    }
    field.didChange(value);
    setState(() {
      _error = null;
      if (end) {
        _end = value;
      } else {
        _start = value;
      }
    });
  }

  // Keep the UUID for retries if a response is lost after the insert.
  String _newEventId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _publish() async {
    if (_publishing || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final groupId = _groupId!;
    setState(() {
      _publishing = true;
      _error = null;
    });

    final ClubEvent event;
    try {
      event = await widget.backend.publishEvent(
        eventId: _publicationIds.putIfAbsent(groupId, _newEventId),
        groupId: groupId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        startsAt: _start!,
        endsAt: _end,
        location: _location.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _publishing = false;
        _error = 'Could not publish. Check your connection and publishing access, then try again.';
      });
      return;
    }
    if (!mounted) return;

    _form.currentState!.reset();

    _title.clear();
    _description.clear();
    _location.clear();
    _publicationIds.clear();
    setState(() {
      _publishing = false;
      _groupId = _initialGroup;
      _formGeneration++;
      _start = null;
      _end = null;
    });
    widget.onPublished(event);
  }

  Widget _dateField({required bool end}) => FormField<DateTime>(
    validator: (value) {
      if (!end && value == null) return 'Choose a start date and time.';
      if (end && value != null && _start != null && value.isBefore(_start!)) {
        return 'End must be at or after the start.';
      }
      return null;
    },
    builder: (field) {
      final value = field.value;
      final l10n = MaterialLocalizations.of(context);
      final label = end
          ? 'End date and time (optional)'
          : 'Start date and time';
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: field.errorText,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _publishing
                    ? null
                    : () => _pickDateTime(field, end: end),
                child: Text(
                  value == null
                      ? 'Choose ${end ? 'end' : 'start'}'
                      : '${l10n.formatFullDate(value)} · ${TimeOfDay.fromDateTime(value).format(context)}',
                ),
              ),
            ),
            if (end && value != null)
              IconButton(
                tooltip: 'Clear end date and time',
                onPressed: _publishing
                    ? null
                    : () {
                        field.didChange(null);
                        setState(() => _end = null);
                      },
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
      );
    },
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    String requiredMessage, {
    int minLines = 1,
  }) => TextFormField(
    controller: controller,
    enabled: !_publishing,
    decoration: InputDecoration(labelText: label),
    minLines: minLines,
    maxLines: minLines == 1 ? 1 : null,
    validator: (value) =>
        value == null || value.trim().isEmpty ? requiredMessage : null,
  );

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Form(
        key: _form,
        child: ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Create event',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey((
                _formGeneration,
                widget.groups.map((group) => group.id).join(','),
              )),
              initialValue: _groupId,
              decoration: const InputDecoration(labelText: 'Organization'),
              isExpanded: true,
              items: [
                for (final group in widget.groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text(group.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _publishing ? null : (id) => _groupId = id,
              validator: (id) => widget.groups.any((group) => group.id == id)
                  ? null
                  : 'Choose an authorized organization.',
            ),
            const SizedBox(height: 12),
            _textField(_title, 'Event title', 'Enter an event title.'),
            const SizedBox(height: 12),
            _textField(
              _description,
              'Full description',
              'Enter a description.',
              minLines: 3,
            ),
            const SizedBox(height: 12),
            _dateField(end: false),
            const SizedBox(height: 12),
            _dateField(end: true),
            const SizedBox(height: 12),
            _textField(_location, 'Location', 'Enter a location.'),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const Text('Publishing…')
                  : const Text('Publish event'),
            ),
          ],
        ),
      ),
    ),
  );
}
