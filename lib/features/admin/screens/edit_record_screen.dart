import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class EditRecordScreen extends StatefulWidget {
  final String tableName;
  final Map<String, dynamic>? record;

  const EditRecordScreen({
    super.key,
    required this.tableName,
    this.record,
  });

  @override
  State<EditRecordScreen> createState() => _EditRecordScreenState();
}

class _EditRecordScreenState extends State<EditRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  List<Map<String, dynamic>> _schema = [];
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchema();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSchema() async {
    try {
      final schema = await AdminService.getTableSchema(widget.tableName);
      setState(() {
        _schema = schema;
        _isLoading = false;
      });

      // Initialize controllers for each field
      for (var field in _schema) {
        final fieldName = field['column_name'] as String;
        if (fieldName != 'id') { // Skip id field
          _controllers[fieldName] = TextEditingController(
            text: widget.record?[fieldName]?.toString() ?? '',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schema: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final data = <String, dynamic>{};
      for (var field in _schema) {
        final fieldName = field['column_name'] as String;
        if (fieldName != 'id' && _controllers.containsKey(fieldName)) {
          final value = _controllers[fieldName]!.text;
          if (value.isNotEmpty) {
            // Convert value based on field type
            switch (field['data_type']) {
              case 'integer':
              case 'bigint':
                data[fieldName] = int.tryParse(value);
                break;
              case 'double precision':
              case 'numeric':
                data[fieldName] = double.tryParse(value);
                break;
              case 'boolean':
                data[fieldName] = value.toLowerCase() == 'true';
                break;
              case 'timestamp with time zone':
              case 'timestamp without time zone':
                data[fieldName] = DateTime.tryParse(value)?.toIso8601String();
                break;
              default:
                data[fieldName] = value;
            }
          }
        }
      }

      if (widget.record != null) {
        // Update existing record
        await AdminService.updateRecord(
          widget.tableName,
          widget.record!['id'],
          data,
        );
      } else {
        // Create new record
        await AdminService.createRecord(widget.tableName, data);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.record != null
                  ? 'Record updated successfully'
                  : 'Record created successfully',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving record: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _getFieldLabel(Map<String, dynamic> field) {
    final name = field['column_name'] as String;
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String? _validateField(String? value, Map<String, dynamic> field) {
    if (field['is_nullable'] == false && (value == null || value.isEmpty)) {
      return '${_getFieldLabel(field)} is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.record != null ? 'Edit Record' : 'Create Record',
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._schema.map((field) {
                      final fieldName = field['column_name'] as String;
                      if (fieldName == 'id') return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: TextFormField(
                          controller: _controllers[fieldName],
                          decoration: InputDecoration(
                            labelText: _getFieldLabel(field),
                            border: const OutlineInputBorder(),
                            helperText:
                                'Type: ${field['data_type']} ${field['is_nullable'] ? '(Optional)' : ''}',
                          ),
                          validator: (value) => _validateField(value, field),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveRecord,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.record != null ? 'Update Record' : 'Create Record',
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 