import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _noteController = TextEditingController();
  final String? _selectedLanguage = 'English';
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _voicePath;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _showInput = false;
  String? _errorMessage;
  List<Map<String, dynamic>> notes = [];
  bool _isFetchingNotes = true;

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _startRecording() async {
    if (await Permission.microphone.isGranted) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _isRecording = true;
        _voicePath = path;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _voicePath = path;
    });
  }

  Future<void> _saveNote() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getString('employeeID');
    if (employeeId == null) {
      setState(() {
        _errorMessage = 'Employee ID not found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final uri = Uri.parse('http://10.176.21.109:4000/api/notes');
    var request = http.MultipartRequest('POST', uri);

    request.fields['employee_id'] = employeeId;
    request.fields['note_text'] = _noteController.text;
    request.fields['language'] = _selectedLanguage!;

    if (_voicePath != null && File(_voicePath!).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath('voice', _voicePath!));
    }

    try {
      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully')),
        );
        _noteController.clear();
        setState(() {
          _voicePath = null;
          _isLoading = false;
          _showInput = false;
        });
        await _fetchNotes();
      } else {
        setState(() {
          _errorMessage = 'Failed to save note: ${responseBody.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getString('employeeID');

    if (employeeId == null) {
      setState(() {
        _errorMessage = 'Employee ID not found';
        _isFetchingNotes = false;
      });
      return;
    }

    setState(() {
      _isFetchingNotes = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://10.176.21.109:4000/api/notes/$employeeId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            notes = List<Map<String, dynamic>>.from(data['notes']);
            _isFetchingNotes = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load notes');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching notes: $e';
        _isFetchingNotes = false;
      });
    }
  }

  Future<void> _deleteNote(int id, String? voicePath) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.176.21.109:4000/api/notes/$id'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          notes.removeWhere((note) => note['id'] == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully')),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete note');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting note: ${e.toString()}')),
      );
    }
  }

  Future<void> _playVoice(String? voicePath) async {
    if (voicePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No voice recording available')),
      );
      return;
    }

    final url = 'http://10.176.21.109:4000/$voicePath';
    debugPrint('Attempting to play: $url');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/temp_audio.m4a';
        await File(filePath).writeAsBytes(response.bodyBytes);
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(filePath));
        debugPrint('Local playback started successfully');
      } else {
        throw Exception('Failed to download audio: HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('Playback error: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _fetchNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_showInput)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Note',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isRecording ? _stopRecording : _startRecording,
                            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                            label: Text(_isRecording ? 'Stop Recording' : 'Record Voice'),
                          ),
                          if (_voicePath != null) ...[
                            const SizedBox(width: 16),
                            const Icon(Icons.check, color: Colors.green),
                            const Text('Voice Recorded'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveNote,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Save Note'),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: _isFetchingNotes
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(child: Text(_errorMessage!))
                      : notes.isEmpty
                          ? const Center(child: Text('No notes found'))
                          : ListView.builder(
                              itemCount: notes.length,
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                return Card(
                                  elevation: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: ListTile(
                                    title: Text(
                                      note['note_text'] ?? 'No text',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (note['voice_path'] != null)
                                          IconButton(
                                            icon: const Icon(Icons.play_arrow, color: Colors.blue),
                                            onPressed: () => _playVoice(note['voice_path']),
                                          ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.visibility, color: Colors.green),
                                      onPressed: () => _showNoteDetailsDialog(note),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _showInput = !_showInput;
            if (!_showInput) {
              _noteController.clear();
              _voicePath = null;
              _isRecording = false;
            }
          });
        },
        child: Icon(_showInput ? Icons.close : Icons.add),
      ),
    );
  }

  void _showNoteDetailsDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Note Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Text: ${note['note_text'] ?? 'No text'}'),
            const SizedBox(height: 8),
            if (note['voice_path'] != null)
              Row(
                children: [
                  const Icon(Icons.play_arrow),
                  TextButton(
                    child: const Text('Play Audio'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _playVoice(note['voice_path']);
                    },
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNote(note['id'], note['voice_path']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}