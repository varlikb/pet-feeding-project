import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../models/admin_role.dart';
import 'edit_record_screen.dart';

class ManageTableScreen extends StatefulWidget {
  final String tableName;
  final AdminRole adminRole;

  const ManageTableScreen({
    super.key,
    required this.tableName,
    required this.adminRole,
  });

  @override
  State<ManageTableScreen> createState() => _ManageTableScreenState();
}

class _ManageTableScreenState extends State<ManageTableScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final int _pageSize = 20;
  String? _searchQuery;
  String? _orderBy;
  bool _ascending = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AdminService.fetchTableRecords(
        widget.tableName,
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery,
        orderBy: _orderBy,
        ascending: _ascending,
      );

      setState(() {
        _records = List<Map<String, dynamic>>.from(result['data']);
        _totalRecords = result['total'];
        _totalPages = result['totalPages'];
        _isLoading = false;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading records: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(String id) async {
    try {
      await AdminService.deleteRecord(widget.tableName, id);
      _loadRecords();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting record: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${_formatTableName(widget.tableName)}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = null;
                                  _currentPage = 1;
                                });
                                _loadRecords();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        _searchQuery = value.isNotEmpty ? value : null;
                        _currentPage = 1;
                      });
                      _loadRecords();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditRecordScreen(
                          tableName: widget.tableName,
                          record: null, // null means creating new record
                        ),
                      ),
                    ).then((value) {
                      if (value == true) {
                        _loadRecords();
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(child: Text('No records found'))
                    : ListView.builder(
                        itemCount: _records.length,
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(
                                _getRecordTitle(record),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(_getRecordSubtitle(record)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => EditRecordScreen(
                                            tableName: widget.tableName,
                                            record: record,
                                          ),
                                        ),
                                      ).then((value) {
                                        if (value == true) {
                                          _loadRecords();
                                        }
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Delete'),
                                          content: const Text(
                                            'Are you sure you want to delete this record?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                _deleteRecord(record['id']);
                                              },
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (!_isLoading && _totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() {
                              _currentPage--;
                            });
                            _loadRecords();
                          }
                        : null,
                  ),
                  Text('Page $_currentPage of $_totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() {
                              _currentPage++;
                            });
                            _loadRecords();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTableName(String tableName) {
    return tableName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getRecordTitle(Map<String, dynamic> record) {
    // Customize the title based on the table
    switch (widget.tableName) {
      case 'profiles':
        return record['name'] ?? record['email'] ?? 'Unnamed Profile';
      case 'pets':
        return record['name'] ?? 'Unnamed Pet';
      case 'devices':
        return record['name'] ?? record['device_key'] ?? 'Unnamed Device';
      case 'feeding_records':
        return 'Feeding on ${record['feeding_time'] ?? 'Unknown Date'}';
      case 'feeding_schedules':
        return 'Schedule for ${record['start_time'] ?? 'Unknown Time'}';
      case 'pet_device_assignments':
        return 'Assignment ${record['id']}';
      case 'admin_users':
        return record['role'] ?? 'Unknown Role';
      default:
        return record['id']?.toString() ?? 'Unknown Record';
    }
  }

  String _getRecordSubtitle(Map<String, dynamic> record) {
    // Customize the subtitle based on the table
    switch (widget.tableName) {
      case 'profiles':
        return record['email'] ?? '';
      case 'pets':
        return 'Owner: ${record['user_id']}';
      case 'devices':
        return 'Key: ${record['device_key']}';
      case 'feeding_records':
        return 'Amount: ${record['amount']}g';
      case 'feeding_schedules':
        return 'Amount: ${record['amount']}g';
      case 'pet_device_assignments':
        return 'Pet: ${record['pet_id']}, Device: ${record['device_id']}';
      case 'admin_users':
        return 'User ID: ${record['user_id']}';
      default:
        return 'ID: ${record['id']}';
    }
  }
} 