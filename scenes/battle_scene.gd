extends Node2D
class_name BattleScene

@onready var cam: Camera2D = $cam;

@onready var background = BattleSceneHelper.Background.new(
  [$bg_root/lg_cloud_2, $bg_root/lg_cloud],
  [$bg_root/md_cloud_2, $bg_root/md_cloud],
  [$bg_root/sm_cloud_2, $bg_root/sm_cloud],
);
@onready var player = BattleSceneHelper.CombatUnit.new(
  $path_left/path_follow/battle_char,
  $path_left/path_follow,
  $path_left,
  $ui_root/ui/player_info/hbox/combat_unit_info/vbox/healthbar,
  $ui_root/ui/player_info/hbox/combat_unit_info/vbox/panel/vbox/name,
  $ui_root/ui/player_info/hbox/bust,
);
@onready var npc = BattleSceneHelper.CombatUnit.new(
  $path_right/path_follow/battle_char,
  $path_right/path_follow,
  $path_right,
  $ui_root/ui/npc_info/hbox/combat_unit_info/vbox/healthbar,
  $ui_root/ui/npc_info/hbox/combat_unit_info/vbox/panel/vbox/name,
  $ui_root/ui/npc_info/hbox/bust,
);
@onready var ui: Control = $ui_root/ui;
@onready var npc_turn_ui: PanelContainer = $ui_root/ui/npc_turn;
@onready var player_choices: BoxContainer = $ui_root/ui/player_choices;
@onready var player_choices_btn: MenuButton = $ui_root/ui/player_choices/btn;
@onready var player_inventory_grid: GridContainer = $ui_root/ui/player_inventory/panel/grid;
@onready var player_inventory_panel: PanelContainer = $ui_root/ui/player_inventory/panel;
@onready var player_inventory_ui_root: Control = $ui_root/ui/player_inventory;
@onready var action_counter_container: BoxContainer = $ui_root/ui/action_counter;
@onready var action_counter_progress_bar: ProgressBar = $ui_root/ui/action_counter/progress_bar;

@export var is_player_turn = true;
@export var std_cam_zoom: Vector2 = Vector2(0.5, 0.5);

var player_inventory_size = 9;
var player_inventory_item_types = [];
var round_happening = false;
var parried = false;
var player_init_position = Vector2(2, 0);
var npc_init_position = Vector2(1020, 0);
var attack_position_offset = Vector2(175, 0);
var rng = RandomNumberGenerator.new();
var qte_current_action_count = 0;
var qte_total_actions = 5;
var qte_min_x = 100;
var qte_max_x = 850;
var qte_min_y = 160;
var qte_max_y = 540;
var std_tween_time = 1;

var qte_items: Array[BattleSceneHelper.QTEItem] = [];

var qte_item_metadata: Dictionary = {
  "up": BattleSceneHelper.QTEItemMetaData.new(
    preload("res://art/my/ui/qte_btn/up/normal.png"),
  ),
  "down": BattleSceneHelper.QTEItemMetaData.new(
    preload("res://art/my/ui/qte_btn/down/normal.png"),
  ),
  "left": BattleSceneHelper.QTEItemMetaData.new(
    preload("res://art/my/ui/qte_btn/left/normal.png"),
  ),
  "right": BattleSceneHelper.QTEItemMetaData.new(
    preload("res://art/my/ui/qte_btn/right/normal.png"),
  ),
};

@onready var player_info_controller = $ui_root/ui/player_info/hbox/combat_unit_info/vbox/panel/vbox/controller;

var paralyzed_icon = preload("res://art/my/items/paralyzed.png");
var posion_icon = preload("res://art/my/items/posion.png");
var strength_icon = preload("res://art/my/items/strength.png");
var default_icon_size = 150;

var qte_all_keys = qte_item_metadata.keys();

func _ready():
  var player_choices_popup = player_choices_btn.get_popup();
  player_choices_popup.connect("id_pressed", on_player_choices_menu_item_pressed);
  player_inventory_ui_root.modulate.a = 0;
  init_player_inventory_items();
  update_player_inventory();
  self.modulate.a = 0;
  ui.modulate.a = 0;
  action_counter_container.modulate.a = 0;
  cam.zoom = std_cam_zoom;
  var scene_tween_time = std_tween_time;
  var scene_tween = create_tween();
  scene_tween.tween_property(self, "modulate:a", 1, scene_tween_time).set_trans(Tween.TRANS_EXPO);
  var ui_tween_time = std_tween_time;
  var ui_tween = create_tween();
  ui_tween.tween_property(ui, "modulate:a", 1, ui_tween_time).set_trans(Tween.TRANS_EXPO);
  npc_turn_ui.modulate.a = 0;
  _init_bg();
  var player_data = AppState.data[Constants.player];
  var player_combat_unit_data_type = player_data["combat_unit_data_type"];
  player.unit_data = CombatUnitData.entries[player_combat_unit_data_type];
  var npc_data = AppState.data[Constants.npc];
  var npc_combat_unit_data_type = npc_data["combat_unit_data_type"];
  npc.unit_data = CombatUnitData.entries[npc_combat_unit_data_type];
  player.battle_char.update_sprite_texture(player.unit_data.sprite_path);
  player.battle_char.health = player_data.get("health", CombatUnitData.default_max_health * player.unit_data.health_modifier);
  npc.battle_char.update_sprite_texture(npc.unit_data.sprite_path);
  npc.battle_char.health = npc_data.get("health", CombatUnitData.default_max_health * npc.unit_data.health_modifier);
  to_player(player);
  update_bust_texture(player);
  update_bust_texture(npc);
  if npc_combat_unit_data_type == player_combat_unit_data_type:
    npc.battle_char.modulate = Color(0.8, 0.8, 0.8);
    npc.bust.modulate = Color(0.8, 0.8, 0.8);
  player.battle_char.idle();
  npc.battle_char.idle();
  var player_path_points: Array[Vector2] = player.unit_data.get_path_points.call(player_init_position, npc_init_position - attack_position_offset)
  player.path.curve.clear_points();
  for i in range(player_path_points.size() - 1, -1, -1):
    var point = player_path_points[i];
    player.path.curve.add_point(point);
  var npc_path_points: Array[Vector2] = npc.unit_data.get_path_points.call(player_init_position + attack_position_offset, npc_init_position)
  npc.path.curve.clear_points();
  for point in npc_path_points:
    npc.path.curve.add_point(point);
  player.name.text = player.unit_data.name;
  npc.name.text = npc.unit_data.name;
  _update_unit_health_bar(player);
  _update_unit_health_bar(npc);
  await get_tree().create_timer(max(scene_tween_time, ui_tween_time)).timeout;

func init_player_inventory_items():
  # TODO: move inventory items out into AppState.data
  for i in player_inventory_size - 1:
    if i < 6:
      if i % 3 == 0:
        player_inventory_item_types.append(BattleSceneHelper.PlayerInventoryItemType.PARALYZED);
      elif i % 2 == 0:
        player_inventory_item_types.append(BattleSceneHelper.PlayerInventoryItemType.POSION);
      else:
        player_inventory_item_types.append(BattleSceneHelper.PlayerInventoryItemType.STRENGTH);

func update_player_inventory():
  for n in player_inventory_grid.get_children():
    player_inventory_grid.remove_child(n);
  # TODO: move inventory items out into AppState.data
  for i in player_inventory_size - 1:
    var panel = PanelContainer.new();
    if i < 6 and player_inventory_item_types.size() > i:
      var button = TextureButton.new();
      button.button_up.connect(func(): _on_inventory_item_selected(i));
      if player_inventory_item_types[i] == BattleSceneHelper.PlayerInventoryItemType.PARALYZED:
        button.texture_normal = paralyzed_icon;
      elif player_inventory_item_types[i] == BattleSceneHelper.PlayerInventoryItemType.POSION:
        button.texture_normal = posion_icon;
      else:
        button.texture_normal = strength_icon;
      panel.add_child(button);
    else:
      panel.custom_minimum_size = Vector2(default_icon_size, default_icon_size);
    player_inventory_grid.add_child(panel);
    
func _on_inventory_item_selected(idx):
  # TODO: apply the debuff or buff to the player or npc depending
  var item_type = player_inventory_item_types.pop_at(idx);
  update_player_inventory();
  var tween = create_tween();
  tween.tween_property(player_inventory_ui_root, "modulate:a", 0, std_tween_time).set_trans(Tween.TRANS_EXPO);

func to_player(player_: BattleSceneHelper.CombatUnit):
  player_info_controller.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;
  player_info_controller.text = Constants.player;
  player_.battle_char.to_player();
  player_.bust.flip_h = true;
  player_.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT;
  player_.health_bar.fill_mode = TextureProgressBar.FillMode.FILL_LEFT_TO_RIGHT;
  player_.is_player = true;

func _input(event: InputEvent):
  if round_happening:
    qte_attempt(event);
    return;
  SceneHelper.process_input(event);

func qte_attempt(event: InputEvent):
  var qte_item = get_qte_item(qte_current_action_count);
  if not qte_item: return;
  if qte_item and event.is_action_pressed(qte_item.key):
    qte_event_update();

func update_bust_texture(combat_unit: BattleSceneHelper.CombatUnit):
  var texture = load(combat_unit.unit_data.bust_path);
  if texture and texture is Texture:
    combat_unit.bust.texture = texture;

func _update_unit_health_bar(combat_unit: BattleSceneHelper.CombatUnit):
  AppState.insert_data(Constants.player if combat_unit.is_player else Constants.npc, { "health": combat_unit.battle_char.health });
  combat_unit.health_bar.value = (combat_unit.battle_char.health / CombatUnitData.default_max_health) * 100;

func full_round(attacker: BattleSceneHelper.CombatUnit, defender: BattleSceneHelper.CombatUnit):
  await attack_sequence(attacker, defender, 1, false);
  is_player_turn = !is_player_turn;
  await get_tree().create_timer(0.5).timeout;
  var did_battle_end = defender.battle_char.health <= 0;
  var winner = attacker if did_battle_end else defender;
  if not did_battle_end:
    var cam_tween_time = std_tween_time;
    var cam_tween = create_tween();
    cam_tween.tween_property(cam, "zoom", Vector2(0.65, 0.65), cam_tween_time).set_trans(Tween.TRANS_EXPO);
    var npc_turn_ui_tween = create_tween();
    npc_turn_ui_tween.tween_property(npc_turn_ui, "modulate:a", 1, std_tween_time).set_trans(Tween.TRANS_EXPO);
    await npc_turn_ui_tween.finished;
    await get_tree().create_timer(0.5).timeout;
    var npc_turn_ui_tween_out_time = std_tween_time;
    var npc_turn_ui_tween_out = create_tween();
    npc_turn_ui_tween_out.tween_property(npc_turn_ui, "modulate:a", 0, npc_turn_ui_tween_out_time).set_trans(Tween.TRANS_EXPO);
    var progress_bar_tween_time = std_tween_time;
    var progress_bar_tween = create_tween();
    progress_bar_tween.tween_property(action_counter_container, "modulate:a", 1, progress_bar_tween_time).set_trans(Tween.TRANS_EXPO);
    await get_tree().create_timer(max(npc_turn_ui_tween_out_time, cam_tween_time, progress_bar_tween_time)).timeout;
    await get_tree().create_timer(0.5).timeout;
    await attack_sequence(defender, attacker, 5, true, Tween.TRANS_LINEAR);
    var player_choices_tween_time = std_tween_time;
    var player_choices_tween = create_tween();
    player_choices_tween.tween_property(player_choices, "modulate:a", 1, player_choices_tween_time).set_trans(Tween.TRANS_EXPO);
    cam_tween = create_tween();
    cam_tween.tween_property(cam, "zoom", std_cam_zoom, cam_tween_time).set_trans(Tween.TRANS_EXPO);
    progress_bar_tween = create_tween();
    progress_bar_tween.tween_property(action_counter_container, "modulate:a", 0, progress_bar_tween_time).set_trans(Tween.TRANS_EXPO);
    await get_tree().create_timer(max(npc_turn_ui_tween_out_time, cam_tween_time, progress_bar_tween_time)).timeout;
    action_counter_progress_bar.value = 0;
    did_battle_end = defender.battle_char.health <= 0;
    if did_battle_end:
      winner = attacker;
    did_battle_end = attacker.battle_char.health <= 0;
    if did_battle_end:
      winner = defender;
  if did_battle_end:
    end_battle_scene(winner);
  AppState.save_session();
  round_happening = false;

func deal_damage(damage_dealer: BattleSceneHelper.CombatUnit, damage_taker: BattleSceneHelper.CombatUnit):
  print(CombatUnitData.default_damage * damage_dealer.unit_data.damage_modifier);
  damage_taker.battle_char.take_damage(CombatUnitData.default_damage * damage_dealer.unit_data.damage_modifier);
  _update_unit_health_bar(damage_taker);

func attack_sequence(attacker: BattleSceneHelper.CombatUnit, defender: BattleSceneHelper.CombatUnit, total_atk_time: float, is_npc_turn: bool, atk_trans: Tween.TransitionType = Tween.TRANS_EXPO):
  create_qte_items(is_npc_turn);
  attacker.battle_char.preatk();
  defender.battle_char.readied();
  var atk_path_follow_tween = create_tween();
  atk_path_follow_tween.tween_property(attacker.path_follow, "progress_ratio", 1, total_atk_time).set_trans(atk_trans);
  await atk_path_follow_tween.finished;
  attacker.battle_char.postatk();
  var damage_taker = defender;
  var damage_dealer = attacker;
  if is_npc_turn and parried:
    damage_taker = attacker;
    damage_dealer = defender;
    defender.battle_char.postatk();
  deal_damage(damage_dealer, damage_taker);
  destory_qte_btns(is_npc_turn);
  # HACK: to let the postatk frame show for a second
  await get_tree().create_timer(1).timeout;
  attacker.battle_char.idle();
  defender.battle_char.idle();
  var atk_path_follow_tween_out = create_tween();
  atk_path_follow_tween_out.tween_property(attacker.path_follow, "progress_ratio", 0, std_tween_time).set_trans(Tween.TRANS_CUBIC);
  return await atk_path_follow_tween_out.finished;

func _init_bg_cloud_movements(clouds: Array[Sprite2D], start_x: float, end_x: float, total_move_secs: float, spacer: float):
  for cloud in clouds:
    cloud.position.x = start_x;
    cloud.visible = true;
    var timer_wait = total_move_secs * spacer;
    var cloud_tween = create_tween();
    cloud_tween.tween_property(cloud, "position:x", end_x, total_move_secs).set_trans(Tween.TRANS_LINEAR);
    cloud_tween.tween_callback(func(): cloud.position.x = start_x).set_delay(0.1);
    cloud_tween.set_loops(-1);
    await get_tree().create_timer(timer_wait).timeout;

func _hide_bg_eles(sprites: Array[Sprite2D]):
  for sprite in sprites:
    sprite.visible = false;

func _init_bg():
  _hide_bg_eles(background.lg_clouds);
  _hide_bg_eles(background.md_clouds);
  _hide_bg_eles(background.sm_clouds);
  _init_bg_cloud_movements(background.lg_clouds, -1200, 3300, 60, 0.6);
  _init_bg_cloud_movements(background.md_clouds, 2800, -1000, 65, 0.5);
  _init_bg_cloud_movements(background.sm_clouds, -800, 2500, 90, 0.1);

func qte_event_update():
  if qte_current_action_count < qte_total_actions:
    hide_qte_item();
    qte_current_action_count = qte_current_action_count + 1;
    action_counter_progress_bar.value = (qte_current_action_count * 100) / float(qte_total_actions);
    parried = qte_current_action_count == qte_total_actions;
    show_qte_item();

func hide_qte_item():
  var qte_item = get_qte_item(qte_current_action_count);
  if not qte_item: return;
  qte_item.button.disabled = true;
  var qte_tween = create_tween().set_parallel(true);
  qte_tween.tween_property(qte_item.button, "modulate", Color(0.8, 0.8, 0.8), 0.2).set_trans(Tween.TRANS_LINEAR);
  qte_tween.tween_property(qte_item.box, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_EXPO);

func show_qte_item():
  var qte_item = get_qte_item(qte_current_action_count);
  if not qte_item: return;
  qte_item.button.disabled = false;
  var qte_box_tween = create_tween();
  qte_box_tween.tween_property(qte_item.box, "modulate:a", 1, 0.5).set_trans(Tween.TRANS_EXPO);

func get_qte_item(index):
  if index >= qte_items.size(): return;
  return qte_items[index];

func _on_qte_btn_pressed():
  qte_event_update();

func create_qte_items(is_npc_turn):
  if not is_npc_turn: return;
  for i in qte_total_actions:
    qte_items.append(create_qte_item());
  var qte_item = get_qte_item(qte_current_action_count);
  if not qte_item: return;
  qte_item.box.visible = true;
  var qte_box_tween = create_tween();
  qte_box_tween.tween_property(qte_item.box, "modulate:a", 1, 0.5).set_trans(Tween.TRANS_EXPO);
  qte_item.button.disabled = false;

func _on_end_battle_scene():
  SceneSwitcher.change_scene("res://scenes/title_scene.tscn", {})

func end_battle_scene(combat_unit: BattleSceneHelper.CombatUnit):
  var box = BoxContainer.new();
  box.anchor_right = 0.5;
  box.anchor_left = 0.5;
  box.anchor_bottom = 0.5;
  box.anchor_top = 0.5;
  box.grow_horizontal = 2
  box.grow_vertical = 2
  # box.layout_mode;
  # box.anchors_preset;
  var button = Button.new();
  var result = "Loses" if not combat_unit.is_player else "Wins"
  button.text = "Player " + result + "!";
  # button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
  button.focus_entered.connect(_on_end_battle_scene);
  button.theme_type_variation = &"ButtonLarge";
  box.add_child(button);
  ui.add_child(box);

func create_qte_item():
  var box = BoxContainer.new();
  var button = TextureButton.new();
  box.scale = Vector2(0.7, 0.7);
  button.focus_entered.connect(_on_qte_btn_pressed);
  box.position = Vector2(
    rng.randf_range(qte_min_x, qte_max_x),
    rng.randf_range(qte_min_y, qte_max_y)
  );
  var key = qte_all_keys[rng.randf_range(0, qte_all_keys.size() - 1)];
  button.texture_normal = qte_item_metadata[key].normal;
  button.disabled = true;
  box.modulate.a = 0;
  box.add_child(button);
  ui.add_child(box);
  return BattleSceneHelper.QTEItem.new(key, box, button);

func destory_qte_btns(is_npc_turn):
  if not is_npc_turn: return;
  for qte_item in qte_items:
    ui.remove_child(qte_item.box);
  qte_items = [];

func on_player_choices_menu_item_pressed(id):
  match id:
    BattleSceneHelper.PlayerChoicesMenuPopupItem.ATTACK:
      if not round_happening and is_player_turn and player.path_follow.progress_ratio == 0 and npc.path_follow.progress_ratio == 0:
        round_happening = true;
        player_inventory_ui_root.modulate.a = 0;
        var player_choices_tween_out = create_tween();
        player_choices_tween_out.tween_property(player_choices, "modulate:a", 0, std_tween_time).set_trans(Tween.TRANS_EXPO);
        is_player_turn = !is_player_turn;
        parried = false;
        qte_current_action_count = 0;
        full_round(player, npc);
    BattleSceneHelper.PlayerChoicesMenuPopupItem.INVENTORY:
        player_inventory_ui_root.modulate.a = 1;
        # TODO: end player turn and perform npc turn
