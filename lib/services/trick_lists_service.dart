import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trick_list.dart';
import 'auth_service.dart';

/// Trick lists are online-only; there is no offline cache or write queue.
class TrickListsService {
  static final _client = Supabase.instance.client;

  /// Lists of the current user, each with the trick IDs it contains.
  static Future<List<TrickList>> getLists() async {
    if (!AuthService.isLoggedIn) return [];
    final data = await _client
        .from('trick_lists')
        .select('*, trick_list_items(trick_id)')
        .order('created_at', ascending: true);
    return (data as List).map((e) => TrickList.fromJson(e)).toList();
  }

  static Future<List<TrickListItem>> getItems(int listId) async {
    final data = await _client
        .from('trick_list_items')
        .select()
        .eq('list_id', listId)
        .order('position', ascending: true);
    return (data as List).map((e) => TrickListItem.fromJson(e)).toList();
  }

  /// Creates a list; [trickId] (if given) is added to it right away.
  static Future<TrickList> createList(String name, {int? trickId}) async {
    final profile = await AuthService.getCurrentProfile();
    if (profile == null) throw StateError('Not logged in');
    final row = await _client
        .from('trick_lists')
        .insert({'user_id': profile.intId, 'name': name.trim()})
        .select()
        .single();
    final list = TrickList.fromJson(row);
    if (trickId != null) await addTrick(list.id, trickId);
    return TrickList(
      id: list.id,
      name: list.name,
      sortMode: list.sortMode,
      sortDescending: list.sortDescending,
      itemCount: trickId != null ? 1 : 0,
      trickIds: {if (trickId != null) trickId},
    );
  }

  static Future<void> renameList(int listId, String name) => _client
      .from('trick_lists')
      .update({'name': name.trim()}).eq('id', listId);

  static Future<void> deleteList(int listId) =>
      _client.from('trick_lists').delete().eq('id', listId);

  static Future<void> setSort(
          int listId, ListSortMode mode, bool descending) =>
      _client.from('trick_lists').update({
        'sort_mode': mode.index,
        'sort_descending': descending,
      }).eq('id', listId);

  /// Appends the trick at the bottom of the custom order.
  static Future<void> addTrick(int listId, int trickId) async {
    final last = await _client
        .from('trick_list_items')
        .select('position')
        .eq('list_id', listId)
        .order('position', ascending: false)
        .limit(1);
    final next =
        (last as List).isEmpty ? 0 : (last.first['position'] as int) + 1;
    await _client.from('trick_list_items').upsert(
      {'list_id': listId, 'trick_id': trickId, 'position': next},
      onConflict: 'list_id,trick_id',
      ignoreDuplicates: true,
    );
  }

  static Future<void> removeTrick(int listId, int trickId) => _client
      .from('trick_list_items')
      .delete()
      .eq('list_id', listId)
      .eq('trick_id', trickId);

  static Future<void> setChecked(int itemId, bool checked) => _client
      .from('trick_list_items')
      .update({'checked': checked}).eq('id', itemId);

  /// Persists the custom order; [items] must already be in the desired order.
  static Future<void> saveCustomOrder(List<TrickListItem> items) async {
    if (items.isEmpty) return;
    await _client.from('trick_list_items').upsert([
      for (var i = 0; i < items.length; i++)
        {
          'list_id': items[i].listId,
          'trick_id': items[i].trickId,
          'position': i,
        }
    ], onConflict: 'list_id,trick_id');
  }
}
