import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../models/project.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late Box _notes;
  late Box _projects;

  Future<void> init() async {
    _notes = await Hive.openBox('notes');
    _projects = await Hive.openBox('projects');
  }

  // ── Notes ──

  /// Returns all notes decoded from JSON, sorted by createdAt descending.
  /// On decode error, logs via debugPrint and skips the note.
  List<Note> allNotes() {
    final notes = <Note>[];
    try {
      for (final key in _notes.keys) {
        try {
          final value = _notes.get(key);
          final decoded = jsonDecode(value as String) as Map<String, dynamic>;
          notes.add(Note.fromJson(decoded));
        } catch (e) {
          debugPrint('StorageService: Failed to decode note $key: $e');
        }
      }
    } catch (e) {
      debugPrint('StorageService: Error reading notes box: $e');
    }
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  /// Returns all notes for a given projectId, sorted by createdAt descending.
  List<Note> notesForProject(String projectId) {
    return allNotes().where((n) => n.projectId == projectId).toList();
  }

  /// Returns all notes in the Inbox (projectId == ''), sorted by createdAt descending.
  List<Note> inboxNotes() {
    return allNotes().where((n) => n.projectId == '').toList();
  }

  /// Returns a single note by id, or null if not found or decode fails.
  Note? noteById(String id) {
    try {
      final value = _notes.get(id);
      if (value == null) return null;
      final decoded = jsonDecode(value as String) as Map<String, dynamic>;
      return Note.fromJson(decoded);
    } catch (e) {
      debugPrint('StorageService: Failed to get note $id: $e');
      return null;
    }
  }

  /// Saves a note to the box as a JSON string.
  Future<void> saveNote(Note n) async {
    await _notes.put(n.id, jsonEncode(n.toJson()));
  }

  /// Deletes a note by id.
  Future<void> deleteNote(String id) async {
    await _notes.delete(id);
  }

  // ── Projects ──

  /// Returns all projects decoded from JSON, pinned first, then by createdAt descending.
  /// On decode error, logs via debugPrint and skips the project.
  List<Project> allProjects() {
    final projects = <Project>[];
    try {
      for (final key in _projects.keys) {
        try {
          final value = _projects.get(key);
          final decoded = jsonDecode(value as String) as Map<String, dynamic>;
          projects.add(Project.fromJson(decoded));
        } catch (e) {
          debugPrint('StorageService: Failed to decode project $key: $e');
        }
      }
    } catch (e) {
      debugPrint('StorageService: Error reading projects box: $e');
    }
    projects.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return projects;
  }

  /// Returns a single project by id, or null if not found or decode fails.
  Project? projectById(String id) {
    try {
      final value = _projects.get(id);
      if (value == null) return null;
      final decoded = jsonDecode(value as String) as Map<String, dynamic>;
      return Project.fromJson(decoded);
    } catch (e) {
      debugPrint('StorageService: Failed to get project $id: $e');
      return null;
    }
  }

  /// Saves a project to the box as a JSON string.
  Future<void> saveProject(Project p) async {
    await _projects.put(p.id, jsonEncode(p.toJson()));
  }

  /// Deletes a project by id.
  Future<void> deleteProject(String id) async {
    await _projects.delete(id);
  }

  /// Returns the number of notes in a given project.
  int noteCountForProject(String projectId) => notesForProject(projectId).length;
}
