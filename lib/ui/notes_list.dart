import 'package:flutter/material.dart';
import 'package:offline_sync_flutter/ui/add_note.dart';

class NotesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> notes = [
    {
      "title": "Meeting Notes",
      "content": "Discuss Flutter offline sync architecture",
      "liked": true
    },
    {
      "title": "Shopping List",
      "content": "Milk, Bread, Fruits",
      "liked": false
    }
  ];

  final int pendingSync = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text(
          "Offline Notes",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddNoteScreen()),
          );
        },
      ),

      body: Column(
        children: [

          /// Sync Indicator
          Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  "Pending Sync: $pendingSync",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {},
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  note["title"],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  note["content"],
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: Icon(
                              note["liked"]
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: note["liked"]
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                            onPressed: () {},
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}