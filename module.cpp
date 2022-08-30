extern "C" {
#include <lua.h>
}

#define EXPORT                                                                 \
  extern "C" __attribute__((visibility("default"))) __attribute__((used))

#include "grammars.h"
#include "textmate.h"
#include "themes.h"
#include "util.h"

#include <map>

static std::map<int, doc_data_ptr> docs;
static bool has_running_threads = false;

/* paramaters
 * nvim.lua buffer lines are 1-based
 * every reference to a buffer line number passed to these function must be
 * 1-based textmate parser lines are 0-based ... subtract here..
 */

int highlight_is_line_dirty(lua_State *L) {
  int linenr = lua_tonumber(L, -2);
  int docid = lua_tonumber(L, -1);
  int block_line = linenr - 1;

  if (docs.find(docid) == docs.end()) {
    lua_pushnumber(L, 1);
    return 1;
  }

  doc_data_ptr doc = docs[docid];
  block_data_ptr block = doc->block_at(block_line);
  // block_data_ptr prev = doc->previous_block(block_line);

  lua_pushnumber(L, (!block || block->dirty) ? 1 : 0);

  bool _threads = Textmate::has_running_threads();
  if (_threads != has_running_threads) {
    for (auto d : docs) {
      d.second->make_dirty();
    }
    has_running_threads = _threads;
  }
  return 1;
}

int highlight_make_line_dirty(lua_State *L) {
  int linenr = lua_tonumber(L, -2);
  int docid = lua_tonumber(L, -1);
  int block_line = linenr - 1;

  if (docs.find(docid) == docs.end()) {
    return 1;
  }

  doc_data_ptr doc = docs[docid];
  block_data_ptr block = doc->block_at(block_line);
  if (block) {
    // log(">>%d", block_line);
    block->make_dirty();
  }

  return 1;
}

// check and add at every highlight call
// int highlight_line_add_doc(lua_State *L)
// {
//   int docid = lua_tonumber(L, -1);
//   if (docs.find(docid) == docs.end()) {
//     doc = std::make_shared<doc_data_t>();
//     docs[docid] = doc;
//   }
// }

int highlight_remove_doc(lua_State *L) {
  int docid = lua_tonumber(L, -1);
  auto it = docs.find(docid);
  if (it != docs.end()) {
    docs.erase(it);
  }
  return 1;
}

int highlight_line(lua_State *L) {
  const char *p = lua_tostring(L, -4);
  int linenr = lua_tonumber(L, -3);
  int langid = lua_tonumber(L, -2);
  int docid = lua_tonumber(L, -1);

  doc_data_ptr doc;

  if (docs.find(docid) == docs.end()) {
    docs[docid] = std::make_shared<doc_data_t>();
    // docs[docid] = doc;
  }

  // log(">>%d %d %d", linenr, langid, docid);
  // lua_newtable(L);
  // return 1;

  doc = docs[docid];

  std::string code = p;
  std::vector<textstyle_t> res;

  int block_line = linenr - 1;
  block_data_ptr block = doc->block_at(block_line);
  block_data_ptr prev_block = doc->previous_block(block_line);
  block_data_ptr next_block = doc->next_block(block_line);

  std::vector<span_info_t> spans;
  res = Textmate::run_highlighter((char *)code.c_str(), Textmate::language(),
                                  Textmate::theme(), block ? block.get() : NULL,
                                  prev_block ? prev_block.get() : NULL,
                                  next_block ? next_block.get() : NULL, &spans);

  // log("highlight_line %d", block_line);

  lua_newtable(L);

  int row = 1;
  for (auto r : spans) {
    int col = 1;
    lua_newtable(L);
    lua_pushnumber(L, r.start);
    lua_rawseti(L, -2, col++);
    lua_pushnumber(L, r.length);
    lua_rawseti(L, -2, col++);
    lua_pushnumber(L, r.fg.r);
    lua_rawseti(L, -2, col++);
    lua_pushnumber(L, r.fg.g);
    lua_rawseti(L, -2, col++);
    lua_pushnumber(L, r.fg.b);
    lua_rawseti(L, -2, col++);
    lua_pushstring(L, r.scope.c_str());
    lua_rawseti(L, -2, col++);

    lua_rawseti(L, -2, row++);
  }

  return 1;
}

int highlight_set_extensions_dir(lua_State *L) {
  const char *p = lua_tostring(L, -1);
  Textmate::initialize(p);
  log("highlight_set_extensions_dir");
  return 1;
}

int highlight_load_theme(lua_State *L) {
  const char *p = lua_tostring(L, -1);
  int theme_id = Textmate::load_theme(p);
  log("highlight_load_theme %s", p);
  lua_pushnumber(L, theme_id);
  for (auto d : docs) {
    d.second->make_dirty();
  }
  return 1;
}

int highlight_set_theme(lua_State *L) {
  int id = lua_tonumber(L, -1);
  Textmate::set_theme(id);
  for (auto d : docs) {
    d.second->make_dirty();
  }
  return 1;
}

int highlight_load_language(lua_State *L) {
  const char *p = lua_tostring(L, -1);
  int lang_id = Textmate::load_language(p);
  log("highlight_load_language %s %d", p, lang_id);
  lua_pushnumber(L, lang_id);
  return 1;
}

int highlight_set_language(lua_State *L) {
  int id = lua_tonumber(L, -1);
  Textmate::set_language(id);
  return 1;
}

int highlight_add_block(lua_State *L) {
  int linenr = lua_tonumber(L, -2);
  int docid = lua_tonumber(L, -1);

  linenr -= 1;
  if (linenr < 0) return 1;

  if (docs.find(docid) == docs.end()) {
    return 1;
  }

  // log("add %d %d", docid, linenr);
  docs[docid]->add_block_at(linenr);
  return 1;
}

int highlight_remove_block(lua_State *L) {
  int linenr = lua_tonumber(L, -2);
  int docid = lua_tonumber(L, -1);

  linenr -= 1;
  if (linenr < 0) return 1;

  if (docs.find(docid) == docs.end()) {
    return 1;
  }

  docs[docid]->remove_block_at(linenr);
  // log("remove %d %d", docid, linenr);
  return 1;
}

int highlight_themes(lua_State *L) {
  std::vector<list_item_t> items = Textmate::theme_extensions();
  lua_newtable(L);

  int row = 1;
  for (auto r : items) {
    int col = 1;
    lua_newtable(L);
    lua_pushstring(L, r.name.c_str());
    lua_rawseti(L, -2, col++);
    lua_pushstring(L, r.description.c_str());
    lua_rawseti(L, -2, col++);
    lua_pushstring(L, r.value.c_str());
    lua_rawseti(L, -2, col++);

    lua_rawseti(L, -2, row++);
  }

  return 1;
}

int highlight_languages(lua_State *L) {
  std::vector<list_item_t> items = Textmate::grammar_extensions();
  lua_newtable(L);

  int row = 1;
  for (auto r : items) {
    int col = 1;
    lua_newtable(L);
    lua_pushstring(L, r.name.c_str());
    lua_rawseti(L, -2, col++);
    lua_pushstring(L, r.description.c_str());
    lua_rawseti(L, -2, col++);
    lua_pushstring(L, r.value.c_str());
    lua_rawseti(L, -2, col++);

    lua_rawseti(L, -2, row++);
  }

  return 1;
}

int highlight_theme_info(lua_State *L) {
  lua_newtable(L);

  theme_info_t theme = Textmate::theme_info();

  int col = 1;
  lua_newtable(L);
  lua_pushnumber(L, theme.fg_r); // 1
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.fg_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.fg_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.bg_r); // 4
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.bg_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.bg_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.sel_r); // 7
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.sel_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.sel_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.cmt_r); // 10
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.cmt_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.cmt_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.fn_r); // 13
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.fn_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.fn_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.kw_r); // 16
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.kw_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.kw_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.var_r); // 17
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.var_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.var_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.type_r); // 20
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.type_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.type_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.struct_r); // 23
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.struct_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.struct_b);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.ctrl_r); // 26
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.ctrl_g);
  lua_rawseti(L, -2, col++);
  lua_pushnumber(L, theme.ctrl_b);
  lua_rawseti(L, -2, col++);
  return 1;
}

EXPORT int luaopen_textmate(lua_State *L) {
  // Textmate::load_theme_data(THEME_MONOKAI);
  // Textmate::load_language_data(GRAMMAR_CPP);

  lua_newtable(L);
  lua_pushcfunction(L, highlight_line);
  lua_setfield(L, -2, "highlight_line");
  lua_pushcfunction(L, highlight_set_extensions_dir);
  lua_setfield(L, -2, "highlight_set_extensions_dir");
  lua_pushcfunction(L, highlight_load_theme);
  lua_setfield(L, -2, "highlight_load_theme");
  lua_pushcfunction(L, highlight_load_language);
  lua_setfield(L, -2, "highlight_load_language");
  lua_pushcfunction(L, highlight_set_theme);
  lua_setfield(L, -2, "highlight_set_theme");
  lua_pushcfunction(L, highlight_set_language);
  lua_setfield(L, -2, "highlight_set_language");
  lua_pushcfunction(L, highlight_is_line_dirty);
  lua_setfield(L, -2, "highlight_is_line_dirty");
  lua_pushcfunction(L, highlight_make_line_dirty);
  lua_setfield(L, -2, "highlight_make_line_dirty");

  lua_pushcfunction(L, highlight_remove_doc);
  lua_setfield(L, -2, "highlight_remove_doc");
  lua_pushcfunction(L, highlight_add_block);
  lua_setfield(L, -2, "highlight_add_block");
  lua_pushcfunction(L, highlight_remove_block);
  lua_setfield(L, -2, "highlight_remove_block");

  lua_pushcfunction(L, highlight_themes);
  lua_setfield(L, -2, "highlight_themes");
  lua_pushcfunction(L, highlight_theme_info);
  lua_setfield(L, -2, "highlight_theme_info");

  lua_pushcfunction(L, highlight_languages);
  lua_setfield(L, -2, "highlight_languages");
  return 1;
}
