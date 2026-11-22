import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../backend/organizer_backend.dart';
import '../../data/campus_groups.dart';
import '../../widgets/auth_scaffold.dart';

enum _Step { status, category, organization, details, verify, directoryRequest }

class OrganizerPage extends StatefulWidget {
  const OrganizerPage({
    super.key,
    required this.backend,
    required this.fullName,
    this.onboarding = false,
    this.onPermissionsChanged,
  });

  final OrganizerBackend backend;
  final String fullName;
  final bool onboarding;
  final VoidCallback? onPermissionsChanged;

  @override
  State<OrganizerPage> createState() => _OrganizerPageState();
}

class _OrganizerPageState extends State<OrganizerPage> {
  final _form = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _directoryName = TextEditingController();
  _Step _step = _Step.status;
  OrganizerCategory? _category;
  CampusGroup? _group;
  ExecutiveRole? _role;
  ExecutiveDetails? _details;
  String? _applicationId;
  String? _organizationName;
  List<CampusGroup>? _directory;
  List<OrganizerApplication> _applications = const [];
  bool _busy = false;
  bool _directoryRequested = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _name.text = widget.fullName;
    _step = widget.onboarding ? _Step.category : _Step.status;
    if (widget.onboarding) {
      // Offer to resume a request if the app was closed before onboarding ended.
      _run(() async {
        await _refreshApplications();
        if (mounted && _applications.isNotEmpty) _step = _Step.status;
      });
    } else {
      _run(_refreshApplications);
    }
  }

  @override
  void dispose() {
    for (final controller in [_search, _name, _email, _code, _directoryName]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on OrganizerRequestError catch (error) {
      if (mounted) _error = error.message;
    } catch (_) {
      if (mounted) _error = 'Could not complete this step. Check your connection and try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshApplications() async {
    final applications = await widget.backend.fetchOrganizerApplications();
    if (!mounted) return;
    final seen = <String>{};
    _applications = [
      for (final application in applications)
        if (seen.add(application.details.groupId)) application,
    ];
    widget.onPermissionsChanged?.call();
  }

  void _go(_Step step) => setState(() {
    _step = step;
    _error = null;
    _notice = null;
  });

  Future<void> _selectCategory(OrganizerCategory category) => _run(() async {
    final directory =
        _directory ?? await widget.backend.fetchOrganizerDirectory();
    if (!mounted) return;
    _directory = directory;
    _category = category;
    _search.clear();
    _step = _Step.organization;
  });

  void _selectGroup(CampusGroup group) {
    final existing = _applications
        .where((application) => application.details.groupId == group.uuid)
        .firstOrNull;
    if (existing != null &&
        (existing.status == OrganizerStatus.approved ||
            existing.status == OrganizerStatus.pendingReview)) {
      _go(_Step.status);
      return;
    }
    _group = group;
    _organizationName = group.name;
    _name.text = existing?.details.fullName ?? widget.fullName;
    _email.text = existing?.details.email ?? '';
    _role = existing?.details.role;
    _go(_Step.details);
  }

  void _resume(OrganizerApplication application, {bool edit = false}) {
    _details = application.details;
    _applicationId = application.id;
    _organizationName = application.organization;
    _code.clear();
    _group = null;
    if (edit) {
      _name.text = application.details.fullName;
      _email.text = application.details.email;
      _role = application.details.role;
      _go(_Step.details);
    } else {
      _go(_Step.verify);
    }
  }

  Future<void> _send(ExecutiveDetails details) => _run(() async {
    final id = await widget.backend.sendExecutiveCode(details);
    if (!mounted) return;
    _details = details;
    _applicationId = id;
    _code.clear();
    _step = _Step.verify;
    _notice = 'Code sent to ${details.email}. It expires in 10 minutes.';
  });

  void _sendFromForm() {
    if (!_form.currentState!.validate()) return;
    _send((
      groupId: _group?.uuid ?? _details!.groupId,
      fullName: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
      role: _role!,
    ));
  }

  void _verify() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      await widget.backend.verifyExecutiveCode(
        applicationId: _applicationId!,
        groupId: _details!.groupId,
        code: _code.text.trim(),
      );
      if (!mounted) return;
      _code.clear();
      _step = _Step.status;
      await _refreshApplications();
    });
  }

  void _finish() => _run(() async {
    await widget.backend.completeOrganizerOnboarding();
    if (mounted) Navigator.of(context).pop();
  });

  void _requestDirectoryReview() {
    if (!_form.currentState!.validate()) return;
    _run(() async {
      await widget.backend.requestOrganization(
        _directoryName.text.trim(),
        _category!,
      );
      if (!mounted) return;
      _step = _Step.status;
      _directoryRequested = true;
      _directory = null;
      _notice = 'Organization review requested. Check the directory again after McMap reviews it.';
    });
  }

  void _back() {
    final previous = switch (_step) {
      _Step.status || _Step.category || _Step.verify => _Step.status,
      _Step.organization => _Step.category,
      _Step.details => _group == null ? _Step.status : _Step.organization,
      _Step.directoryRequest => _Step.organization,
    };
    _go(previous);
    if (previous == _Step.status) _run(_refreshApplications);
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.status => 'Organizer settings',
      _Step.category => 'Choose organization type',
      _Step.organization => 'Select organization',
      _Step.details => 'Executive information',
      _Step.verify => 'Verify your executive email',
      _Step.directoryRequest => 'Request a directory review',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading:
            _step == _Step.status ||
                (_step == _Step.category && widget.onboarding)
            ? null
            : BackButton(onPressed: _busy ? () {} : _back),
        actions: [
          if (_step == _Step.status)
            IconButton(
              tooltip: 'Refresh organizer status',
              onPressed: _busy ? null : () => _run(_refreshApplications),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error case final error?) AuthError(error),
            if (_notice case final notice?) ...[
              Text(notice),
              const SizedBox(height: 16),
            ],
            if (_step == _Step.status) ..._status(),
            if (_step == _Step.category)
              for (final category in OrganizerCategory.values)
                ListTile(
                  title: Text(category.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _selectCategory(category),
                ),
            if (_step == _Step.organization) ..._organizations(),
            if (_step == _Step.details) _executiveForm(),
            if (_step == _Step.verify) _verificationForm(),
            if (_step == _Step.directoryRequest) _directoryForm(),
            if (widget.onboarding) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _busy ? null : _finish,
                child: Text(
                  _applicationId != null ||
                          _applications.isNotEmpty ||
                          _directoryRequested
                      ? 'Continue to McMap'
                      : 'Set up publishing later',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _status() => [
    for (final application in _applications)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                application.status.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${application.organization} · ${application.details.role.label}',
              ),
              Text(application.details.email),
              if (application.status == OrganizerStatus.pendingReview)
                const Text(
                  'McMap administrators will review your authority to publish.',
                ),
              if (application.reviewNote case final note?) Text(note),
              if (application.status == OrganizerStatus.verifyEmail) ...[
                TextButton(
                  onPressed: _busy ? null : () => _resume(application),
                  child: const Text('Enter verification code'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _resume(application, edit: true),
                  child: const Text('Edit executive information'),
                ),
              ],
              if (application.status == OrganizerStatus.rejected ||
                  application.status == OrganizerStatus.revoked)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _resume(application, edit: true),
                  child: const Text('Apply again'),
                ),
            ],
          ),
        ),
      ),
    const SizedBox(height: 12),
    FilledButton(
      onPressed: _busy ? null : () => _go(_Step.category),
      child: const Text('Request publishing access'),
    ),
  ];

  List<Widget> _organizations() {
    final matches = [
      for (final group in _directory!)
        if (_category!.matches(group.type) &&
            group.searchRank(_search.text) != null)
          group,
    ];
    matches.sort(
      (a, b) =>
          a.searchRank(_search.text)!.compareTo(b.searchRank(_search.text)!),
    );
    return [
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Search organizations',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      if (matches.isEmpty)
        const ListTile(title: Text('No organizations found.')),
      for (final group in matches.take(30))
        ListTile(
          key: ValueKey(group.id),
          title: Text(group.name),
          subtitle: Text(group.type?.label ?? _category!.label),
          onTap: () => _selectGroup(group),
        ),
      if (matches.length > 30)
        const Text('Narrow your search to see more specific results.'),
      TextButton(
        onPressed: () {
          _directoryName.text = _search.text.trim();
          _go(_Step.directoryRequest);
        },
        child: const Text('My organization is missing'),
      ),
      TextButton(
        onPressed: () => _go(_Step.category),
        child: const Text('Change organization type'),
      ),
    ];
  }

  Widget _executiveForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _organizationName!,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _name,
          enabled: !_busy,
          maxLength: 120,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Full name'),
          validator: (value) =>
              value!.trim().isEmpty ? 'Enter your full name.' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ExecutiveRole>(
          initialValue: _role,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Official role'),
          items: [
            for (final role in ExecutiveRole.values)
              DropdownMenuItem(value: role, child: Text(role.label)),
          ],
          onChanged: _busy ? null : (role) => setState(() => _role = role),
          validator: (role) => role == null ? 'Choose your role.' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          maxLength: 254,
          decoration: const InputDecoration(
            labelText: 'Executive email address',
          ),
          validator: (value) =>
              RegExp(
                r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$",
              ).hasMatch(value!.trim().toLowerCase())
              ? null
              : 'Enter a valid executive email address.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _sendFromForm,
          child: const Text('Send verification code'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _go(_group == null ? _Step.status : _Step.organization),
          child: Text(
            _group == null
                ? 'Back to organizer settings'
                : 'Change organization',
          ),
        ),
      ],
    ),
  );

  Widget _verificationForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$_organizationName · ${_details!.role.label}'),
        Text('Enter the 8-digit code sent to ${_details!.email}.'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 8,
          decoration: const InputDecoration(labelText: 'Verification code'),
          validator: (value) =>
              value?.length == 8 ? null : 'Enter the 8-digit code.',
          onFieldSubmitted: (_) => _verify(),
        ),
        FilledButton(
          onPressed: _busy ? null : _verify,
          child: const Text('Verify email'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _send(_details!),
          child: const Text('Resend code'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  _name.text = _details!.fullName;
                  _email.text = _details!.email;
                  _role = _details!.role;
                  _go(_Step.details);
                },
          child: const Text('Edit executive information'),
        ),
      ],
    ),
  );

  Widget _directoryForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_category!.label),
        const SizedBox(height: 12),
        TextFormField(
          controller: _directoryName,
          enabled: !_busy,
          maxLength: 150,
          decoration: const InputDecoration(
            labelText: 'Official organization name',
          ),
          validator: (value) =>
              value!.trim().isEmpty ? 'Enter the organization name.' : null,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _requestDirectoryReview,
          child: const Text('Submit for review'),
        ),
        TextButton(
          onPressed: _busy ? null : () => _go(_Step.organization),
          child: const Text('Back to organization search'),
        ),
      ],
    ),
  );
}
