import 'dart:ui' as ui;

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/address_book.dart';
import 'package:flutter_hbb/common/widgets/my_group.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/widgets/popup_menu.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/desktop/widgets/material_mod_popup_menu.dart'
    as mod_menu;
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

const int groupTabIndex = 4;
const String defaultGroupTabname = 'Group';

class StatePeerTab {
  final RxInt currentTab = 0.obs;
  final RxInt tabHiddenFlag = 0.obs;
  final RxList<String> tabNames = [
    'Recent Sessions',
    'Favorites',
    'Discovered',
    'Address Book',
    defaultGroupTabname,
  ].obs;

  StatePeerTab._() {
    tabHiddenFlag.value = (int.tryParse(
            bind.getLocalFlutterConfig(k: 'hidden-peer-card'),
            radix: 2) ??
        0);
    var tabs = _notHiddenTabs();
    currentTab.value =
        int.tryParse(bind.getLocalFlutterConfig(k: 'peer-tab-index')) ?? 0;
    if (!tabs.contains(currentTab.value)) {
      currentTab.value = 0;
    }
  }
  static final StatePeerTab instance = StatePeerTab._();

  check() {
    var tabs = _notHiddenTabs();
    if (filterGroupCard()) {
      if (currentTab.value == groupTabIndex) {
        currentTab.value =
            tabs.firstWhereOrNull((e) => e != groupTabIndex) ?? 0;
        bind.setLocalFlutterConfig(
            k: 'peer-tab-index', v: currentTab.value.toString());
      }
    } else {
      if (gFFI.userModel.isAdmin.isFalse &&
          gFFI.userModel.groupName.isNotEmpty) {
        tabNames[groupTabIndex] = gFFI.userModel.groupName.value;
      } else {
        tabNames[groupTabIndex] = defaultGroupTabname;
      }
      if (tabs.contains(groupTabIndex) &&
          int.tryParse(bind.getLocalFlutterConfig(k: 'peer-tab-index')) ==
              groupTabIndex) {
        currentTab.value = groupTabIndex;
      }
    }
  }

  List<int> currentTabs() {
    var v = List<int>.empty(growable: true);
    for (int i = 0; i < tabNames.length; i++) {
      if (!_isTabHidden(i) && !_isTabFilter(i)) {
        v.add(i);
      }
    }
    return v;
  }

  bool filterGroupCard() {
    if (gFFI.groupModel.users.isEmpty ||
        (gFFI.userModel.isAdmin.isFalse && gFFI.userModel.groupName.isEmpty)) {
      return true;
    } else {
      return false;
    }
  }

  bool _isTabHidden(int tabindex) {
    return tabHiddenFlag & (1 << tabindex) != 0;
  }

  bool _isTabFilter(int tabIndex) {
    if (tabIndex == groupTabIndex) {
      return filterGroupCard();
    }
    return false;
  }

  List<int> _notHiddenTabs() {
    var v = List<int>.empty(growable: true);
    for (int i = 0; i < tabNames.length; i++) {
      if (!_isTabHidden(i)) {
        v.add(i);
      }
    }
    return v;
  }
}

final statePeerTab = StatePeerTab.instance;

class PeerTabPage extends StatefulWidget {
  const PeerTabPage({Key? key}) : super(key: key);
  @override
  State<PeerTabPage> createState() => _PeerTabPageState();
}

class _TabEntry {
  final Widget widget;
  final Function() load;
  _TabEntry(this.widget, this.load);
}

EdgeInsets? _menuPadding() {
  return isDesktop ? kDesktopMenuPadding : null;
}

class _PeerTabPageState extends State<PeerTabPage>
    with SingleTickerProviderStateMixin {
  final List<_TabEntry> entries = [
    _TabEntry(
        RecentPeersView(
          menuPadding: _menuPadding(),
        ),
        bind.mainLoadRecentPeers),
    _TabEntry(
        FavoritePeersView(
          menuPadding: _menuPadding(),
        ),
        bind.mainLoadFavPeers),
    _TabEntry(
        DiscoveredPeersView(
          menuPadding: _menuPadding(),
        ),
        bind.mainDiscover),
    _TabEntry(
        AddressBook(
          menuPadding: _menuPadding(),
        ),
        () => {}),
    _TabEntry(
        MyGroup(
          menuPadding: _menuPadding(),
        ),
        () => {}),
  ];

  @override
  void initState() {
    adjustTab();

    final uiType = bind.getLocalFlutterConfig(k: 'peer-card-ui-type');
    if (uiType != '') {
      peerCardUiType.value = int.parse(uiType) == PeerUiType.list.index
          ? PeerUiType.list
          : PeerUiType.grid;
    }
    super.initState();
  }

  Future<void> handleTabSelection(int tabIndex) async {
    if (tabIndex < entries.length) {
      statePeerTab.currentTab.value = tabIndex;
      entries[tabIndex].load();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      textBaseline: TextBaseline.ideographic,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: Container(
              padding: isDesktop ? null : EdgeInsets.symmetric(horizontal: 2),
              constraints: isDesktop ? null : kMobilePageConstraints,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                      child: visibleContextMenuListener(
                          _createSwitchBar(context))),
                  const PeerSearchBar(),
                  Offstage(
                      offstage: !isDesktop,
                      child: _createPeerViewTypeSwitch(context)
                          .marginOnly(left: 13)),
                ],
              )),
        ),
        _createPeersView(),
      ],
    );
  }

  Widget _createSwitchBar(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return Obx(() {
      var tabs = statePeerTab.currentTabs();
      return ListView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          controller: ScrollController(),
          children: tabs.map((t) {
            return InkWell(
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: statePeerTab.currentTab.value == t
                        ? Theme.of(context).backgroundColor
                        : null,
                    borderRadius: BorderRadius.circular(isDesktop ? 2 : 6),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      translatedTabname(t),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          height: 1,
                          fontSize: 14,
                          color: statePeerTab.currentTab.value == t
                              ? textColor
                              : textColor
                            ?..withOpacity(0.5)),
                    ),
                  )),
              onTap: () async {
                await handleTabSelection(t);
                await bind.setLocalFlutterConfig(
                    k: 'peer-tab-index', v: t.toString());
              },
            );
          }).toList());
    });
  }

  translatedTabname(int index) {
    if (index < statePeerTab.tabNames.length) {
      final name = statePeerTab.tabNames[index];
      if (index == groupTabIndex) {
        if (name == defaultGroupTabname) {
          return translate(name);
        } else {
          return name;
        }
      } else {
        return translate(name);
      }
    }
    assert(false);
    return index.toString();
  }

  Widget _createPeersView() {
    final verticalMargin = isDesktop ? 12.0 : 6.0;
    return Expanded(
        child: Obx(() {
      var tabs = statePeerTab.currentTabs();
      if (tabs.isEmpty) {
        return visibleContextMenuListener(Center(
          child: Text(translate('Right click to select tabs')),
        ));
      } else {
        if (tabs.contains(statePeerTab.currentTab.value)) {
          return entries[statePeerTab.currentTab.value].widget;
        } else {
          statePeerTab.currentTab.value = tabs[0];
          return entries[statePeerTab.currentTab.value].widget;
        }
      }
    }).marginSymmetric(vertical: verticalMargin));
  }

  Widget _createPeerViewTypeSwitch(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    final activeDeco = BoxDecoration(color: Theme.of(context).backgroundColor);
    return Row(
      children: [PeerUiType.grid, PeerUiType.list]
          .map((type) => Obx(
                () => Container(
                  padding: EdgeInsets.all(4.0),
                  decoration: peerCardUiType.value == type ? activeDeco : null,
                  child: InkWell(
                      onTap: () async {
                        await bind.setLocalFlutterConfig(
                            k: 'peer-card-ui-type', v: type.index.toString());
                        peerCardUiType.value = type;
                      },
                      child: Icon(
                        type == PeerUiType.grid
                            ? Icons.grid_view_rounded
                            : Icons.list,
                        size: 18,
                        color:
                            peerCardUiType.value == type ? textColor : textColor
                              ?..withOpacity(0.5),
                      )),
                ),
              ))
          .toList(),
    );
  }

  adjustTab() {
    var tabs = statePeerTab.currentTabs();
    if (tabs.isNotEmpty && !tabs.contains(statePeerTab.currentTab.value)) {
      statePeerTab.currentTab.value = tabs[0];
    }
  }

  Widget visibleContextMenuListener(Widget child) {
    return Listener(
        onPointerDown: (e) {
          if (e.kind != ui.PointerDeviceKind.mouse) {
            return;
          }
          if (e.buttons == 2) {
            showRightMenu(
              (CancelFunc cancelFunc) {
                return visibleContextMenu(cancelFunc);
              },
              target: e.position,
            );
          }
        },
        child: child);
  }

  Widget visibleContextMenu(CancelFunc cancelFunc) {
    return Obx(() {
      final List<MenuEntryBase> menu = List.empty(growable: true);
      for (int i = 0; i < statePeerTab.tabNames.length; i++) {
        if (i == groupTabIndex && statePeerTab.filterGroupCard()) {
          continue;
        }
        int bitMask = 1 << i;
        menu.add(MenuEntrySwitch(
            switchType: SwitchType.scheckbox,
            text: translatedTabname(i),
            getter: () async {
              return statePeerTab.tabHiddenFlag & bitMask == 0;
            },
            setter: (show) async {
              if (show) {
                statePeerTab.tabHiddenFlag.value &= ~bitMask;
              } else {
                statePeerTab.tabHiddenFlag.value |= bitMask;
              }
              await bind.setLocalFlutterConfig(
                  k: 'hidden-peer-card',
                  v: statePeerTab.tabHiddenFlag.value.toRadixString(2));
              cancelFunc();
              adjustTab();
            }));
      }
      return mod_menu.PopupMenu(
          items: menu
              .map((entry) => entry.build(
                  context,
                  const MenuConfig(
                    commonColor: MyTheme.accent,
                    height: 20.0,
                    dividerHeight: 12.0,
                  )))
              .expand((i) => i)
              .toList());
    });
  }
}

class PeerSearchBar extends StatefulWidget {
  const PeerSearchBar({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _PeerSearchBarState();
}

class _PeerSearchBarState extends State<PeerSearchBar> {
  var drawer = false;

  @override
  Widget build(BuildContext context) {
    return drawer
        ? _buildSearchBar()
        : IconButton(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 2),
            onPressed: () {
              setState(() {
                drawer = true;
              });
            },
            icon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).hintColor,
            ));
  }

  Widget _buildSearchBar() {
    RxBool focused = false.obs;
    FocusNode focusNode = FocusNode();
    focusNode.addListener(() => focused.value = focusNode.hasFocus);
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Obx(() => Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).hintColor,
                    ).marginSymmetric(horizontal: 4),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        controller: peerSearchTextController,
                        onChanged: (searchText) {
                          peerSearchText.value = searchText;
                        },
                        focusNode: focusNode,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        cursorColor: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.color
                            ?.withOpacity(0.5),
                        cursorHeight: 18,
                        cursorWidth: 1,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                          hintText:
                              focused.value ? null : translate("Search ID"),
                          hintStyle: TextStyle(
                              fontSize: 14, color: Theme.of(context).hintColor),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    // Icon(Icons.close),
                    IconButton(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 2),
                        onPressed: () {
                          setState(() {
                            peerSearchTextController.clear();
                            peerSearchText.value = "";
                            drawer = false;
                          });
                        },
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).hintColor,
                        )),
                  ],
                ),
              )
            ],
          )),
    );
  }
}
