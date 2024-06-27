import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:playify/playify.dart';
import 'package:retro/alt_menu/alt_menu_item.dart';
import 'package:retro/alt_menu/alt_sub_menu.dart';
import 'package:retro/alt_menu/alt_menu_design.dart';
import 'package:retro/blocs/player/player_bloc.dart';
import 'package:retro/blocs/player/player_event.dart';
import 'package:retro/blocs/songs/song_list.dart';
import 'package:retro/blocs/theme/theme_bloc.dart';
import 'package:retro/blocs/theme/theme_event.dart';
import 'package:retro/blocs/theme/theme_state.dart';
import 'package:retro/coverflow/covercycle.dart';
import 'package:retro/helpers/size_helpers.dart';
import 'package:retro/ipod_menu_widget/ipod_menu_item.dart';
import 'package:retro/ipod_menu_widget/ipod_sub_menu.dart';
import 'package:retro/main.dart';
import 'package:retro/menu.dart';
import 'package:retro/music_models/apple_music/song/song_model.dart';
import 'package:retro/music_models/playlist/playlist_model.dart';
import 'package:retro/music_player_widget/music_player_screen.dart';
import 'package:retro/onboarding/walkthrough.dart'; // Add this line
import 'package:url_launcher/url_launcher.dart';

import 'clickwheel/pan_handlers.dart';
import 'clickwheel/wheel_content.dart';
import 'games/breakout/breakout.dart';
import 'ipod_menu_widget/menu_design.dart';

class IPod extends StatefulWidget {
  final List<Song>? songs;

  IPod({Key? key, this.songs}) : super(key: key);

  @override
  IPodState createState() => IPodState();
}

class IPodState extends State<IPod> {
  final _channel = const MethodChannel("co.retromusic.app");
  bool fetchingAllSongs = false;
  bool playing = false;
  SongInformation? data;
  Shuffle shufflemode = Shuffle.off;
  Repeat repeatmode = Repeat.none;
  var myplayer = Playify();
  List<Artist> artists = [];
  double time = 0.0;
  double volume = 0.0;
  List<String> genres = [];
  String selectedGenre = "";
  List<SongModel>? _songs;
  List<PlaylistModel>? _playlists;
  List<SongModel>? _likedSongs; // Add this line
  bool debugMenu = false;
  PageController? _pageController;
  bool isCoverCycleVisible = true;
  bool isNestedMenu = false;
  final Uri _discord = Uri.parse('https://discord.retromusic.co');
  final Uri _twitter = Uri.parse('https://twitter.com/retro_mp3');
  final Uri _kofi = Uri.parse('https://ko-fi.com/retromp3');
  final Uri _github = Uri.parse('https://github.com/retromp3/retro');

  final PageController _pageCtrl = PageController(viewportFraction: 0.6);

  double? currentPage = 0.0;

  @override
  void initState() {
    mainViewMode = MainViewMode.menu;
    menu = getIPodMenu();
    altMenu = getAltMenu();
    widgetSize = 300.0;
    halfSize = widgetSize / 2;
    cartesianStartX = 1;
    cartesianStartY = 0;
    cartesianStartRadius = 1;
    ticksPerCircle = 20;
    tickAngel = 2 * pi / ticksPerCircle;
    wasExtraRadius = false;
    _songs = [];
    songIDs = [];
    _playlists = [];
    _likedSongs = []; // Add this line
    _pageController = PageController(initialPage: 0);

    PerfectVolumeControl.hideUI = true;

    _channel.setMethodCallHandler((call) async {
      final methodName = call.method;
      switch (methodName) {
        case "nextSongFromWatch":
          musicControls.playNextSong(context);
          return;
        case "prevSongFromWatch":
          musicControls.playPrevSong(context);
          return;
        default:
          return;
      }
    });

    _pageCtrl.addListener(() {
      setState(() {
        currentPage = _pageCtrl.page;
      });
    });
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homePressed(context);
    });
  }

  Widget buildMainView() {
    switch (mainViewMode) {
      case MainViewMode.menu:
        return buildMenu();
      case MainViewMode.player:
        return NowPlayingScreen();
      case MainViewMode.breakoutGame:
        return BreakoutGame(key: breakoutGame);
      default:
        return buildMenu();
    }
  }

  _launchDiscord() async {
    if (!await launchUrl(_discord)) {
      throw Exception('Could not launch $_discord');
    }
  }

  _launchTwitter() async {
    if (!await launchUrl(_twitter)) {
      throw Exception('Could not launch $_twitter');
    }
  }

  _launchKofi() async {
    if (!await launchUrl(_kofi)) {
      throw Exception('Could not launch $_kofi');
    }
  }

  _launchGithub() async {
    if (!await launchUrl(_github)) {
      throw Exception('Could not launch $_github');
    }
  }

  // sends the user back to the menu
  void homePressed(context) {
    setState(() => mainViewMode = MainViewMode.menu);
  }

  // sends the user to the player
  void showPlayer() {
    _pageController!.animateToPage(1, duration: Duration(milliseconds: 200), curve: Curves.easeIn);
    setState(() {
      mainViewMode = MainViewMode.player;
    });
  }

  // sends the user to Breakout
  void showBreakoutGame() {
    _pageController!.animateToPage(2, duration: Duration(milliseconds: 200), curve: Curves.easeIn);
    setState(() {
      mainViewMode = MainViewMode.breakoutGame;
    });
  }

  void _showDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text("Apple Music is currently not supported."),
        content: Text("Follow @retro_mp3 on X (formerly Twitter) for updates."),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text("Close"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void shuffleSongs(context) {
    BlocProvider.of<PlayerBloc>(context).add(ShuffleCalled());
  }

  List<IPodMenuItem> allSongs() {
    List<IPodMenuItem> combineSongs = [];
    List<IPodMenuItem> allPlaylists = _playlistBuilder();
    List<IPodMenuItem> songsInPlaylist = _songsInEachPlaylist();

    for (var i = 0; i < allPlaylists.length; i++) {
      combineSongs.add(allPlaylists[i]);
      for (var j = 0; j < songsInPlaylist.length; j++) {
        combineSongs.add(songsInPlaylist[j]);
      }
    }

    if (_songs == null || _songs!.isEmpty) {
      return [IPodMenuItem(text: 'No songs fetched')];
    }
    List<SongModel> sortedSongs = List.from(_songs!)..sort((a, b) => a.title!.compareTo(b.title!));

    for (var i = 0; i < sortedSongs.length; i++) {
      combineSongs.add(IPodMenuItem(
        text: '${sortedSongs[i].title}',
        subText: '${sortedSongs[i].artistName}',
        onTap: () => BlocProvider.of<PlayerBloc>(context).add(SetQueueItem(sortedSongs[i].songID)),
      ));
    }
    return combineSongs;
  }

  List<IPodMenuItem> _songListBuilder() {
    if (_songs == null || _songs!.isEmpty) {
      return [IPodMenuItem(text: 'No songs fetched')];
    }

    List<SongModel> sortedSongs = List.from(_songs!)..sort((a, b) => a.title!.compareTo(b.title!));

    return sortedSongs
        .map(
          (SongModel song) => IPodMenuItem(
            text: '${song.title}',
            subText: '${song.artistName}',
            onTap: () => BlocProvider.of<PlayerBloc>(context).add(SetQueueItem(song.songID)),
          ),
        )
        .toList();
  }

  List<IPodMenuItem> _likedSongsBuilder() {
    if (_likedSongs == null || _likedSongs!.isEmpty) {
      return [IPodMenuItem(text: 'No liked songs fetched (this is a WIP)')];
    }

    List<SongModel> sortedLikedSongs = List.from(_likedSongs!)..sort((a, b) => a.title!.compareTo(b.title!));

    return sortedLikedSongs
        .map(
          (SongModel song) => IPodMenuItem(
            text: '${song.title}',
            subText: '${song.artistName}',
            onTap: () => BlocProvider.of<PlayerBloc>(context).add(SetQueueItem(song.songID)),
          ),
        )
        .toList();
  }

  List<IPodMenuItem> _songsInEachPlaylist() {
    final List<IPodMenuItem> items = _songs!
        .map(
          (SongModel song) => IPodMenuItem(
            text: '${song.title}',
            subText: '${song.artistName}',
            onTap: () => BlocProvider.of<PlayerBloc>(context).add(SetQueueItem(song.songID)),
          ),
        )
        .toList();

    return items;
  }

  List<IPodMenuItem> _playlistBuilder() {
    if (_playlists == null || _playlists!.isEmpty) {
      return [IPodMenuItem(text: 'No playlists fetched')];
    }
    final IPodSubMenu songsInPlaylistMenu = IPodSubMenu(
      caption: MenuCaption(text: "Songs"),
      itemsBuilder: _songsInEachPlaylist,
    );
    return _playlists!
        .map(
          (PlaylistModel playlist) => IPodMenuItem(
            text: '${playlist.name}',
            subMenu: songsInPlaylistMenu,
            onTap: () {
              BlocProvider.of<SongListBloc>(context).add(SongListFetched(playlist.id));
              setState(() {
                isCoverCycleVisible = false;
              });
            },
          ),
        )
        .toList();
  }

  void _songStateListener(BuildContext context, SongListState state) {
    if (state is SongListFetchSuccess) {
      _songs = state.songList;
      songIDs = state.songList.map((SongModel song) => song.songID).toList();
      _playlists = state.playlists;
      menuKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SongListBloc, SongListState>(
      listener: _songStateListener,
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 25, left: 8, right: 8),
              constraints: BoxConstraints(minHeight: 100, maxHeight: 320),
              height: displayHeight(context) * 0.8,
              width: displayWidth(context) * 0.96,
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c1c),
                borderRadius: BorderRadius.all(
                  Radius.circular(8),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(5.8),
                    child: Stack(
                      children: <Widget>[
                        // Position CoverCycle on the right half of the screen
                        AnimatedPositioned(
                          curve: Curves.easeIn,
                          duration: const Duration(milliseconds: 200),
                          right: isCoverCycleVisible ? 0 : -MediaQuery.of(context).size.width / 2.15,
                          top: 0,
                          bottom: 0,
                          width: displayWidth(context) / 2.15,
                          child: AnimatedOpacity(
                            opacity: isCoverCycleVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: CoverCycle(autoScroll: true),
                          ),
                        ),
                        // Your PageView goes here
                        PageView(
                          controller: _pageController,
                          children: <Widget>[
                            FractionallySizedBox(
                              widthFactor: isCoverCycleVisible ? 0.5 : 1.0,
                              alignment: Alignment.centerLeft,
                              child: buildMenu(),
                            ),
                            NowPlayingScreen(),
                            BreakoutGame(key: breakoutGame),
                          ],
                        ),
                        AnimatedPositioned(
                          curve: Curves.easeIn,
                          duration: const Duration(milliseconds: 200),
                          right: isCoverCycleVisible ? 0 : -MediaQuery.of(context).size.width / 2.15,
                          top: 0,
                          bottom: 0,
                          width: displayWidth(context) / 2.15,
                          child: AnimatedOpacity(
                            opacity: isCoverCycleVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: CoverCycle(autoScroll: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(5.5),
                    child: AnimatedOpacity(
                      opacity: popUp ? 1.0 : 0.0,
                      duration: Duration(milliseconds: 200),
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                  ),
                  altIpodMenu(context),
                ],
              ),
            ),
            Spacer(),
            BlocBuilder<ThemeBloc, ThemeState>(
              buildWhen: (ThemeState prev, ThemeState cur) => prev.wheelColor != cur.wheelColor,
              builder: clickWheel,
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }

  Widget menuButton(context) {
    return InkWell(
      onTap: () async {
        if (mainViewMode != MainViewMode.menu) {
          homePressed(context);
          _pageController!.animateToPage(0, duration: Duration(milliseconds: 200), curve: Curves.easeIn);
        }
        if (mainViewMode == MainViewMode.player) {
          setState(() {
            isCoverCycleVisible = true;
          });
        } else if (popUp == true) {
          setState(() {
            popUp = false;
          });
        } else {
          menuKey.currentState?.back();
          _pageController!.animateToPage(0, duration: Duration(milliseconds: 200), curve: Curves.easeIn);

          if (isCoverCycleVisible == false) {
            setState(() {
              isCoverCycleVisible = true;
            });
          }
        }
        HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
      },
      child: Container(
        child: Text(
          'MENU',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: controlsColor,
          ),
        ),
        alignment: Alignment.topCenter,
        margin: EdgeInsets.only(top: 15),
      ),
    );
  }

  Widget clickWheel(BuildContext context, ThemeState state) {
    switch (state.wheelColor) {
      case WheelColor.black:
        wheelColor = Color(0xFF2D2D2D);
        break;
      case WheelColor.oledBlack:
        wheelColor = Color(0xFF010101);
        break;
      case WheelColor.white:
        wheelColor = Colors.white;
        break;
      case WheelColor.blueMetal:
        wheelColor = Color(0xFFD0E6FB);
        break;
      case WheelColor.pink:
        wheelColor = Color(0xFFFFD3D4);
        break;
      case WheelColor.gray:
        wheelColor = Color(0xFFA7A5A7);
        break;
      case WheelColor.coral:
        wheelColor = Color(0xFFE6756C);
        break;
      case WheelColor.red3ds:
        wheelColor = Color(0xFF822e30);
        break;
      case WheelColor.catFrap:
        wheelColor = Color(0xFF737994);
        break;
      case WheelColor.catLatt:
        wheelColor = Color(0xFF9ca0b0);
        break;
      case WheelColor.catMacc:
        wheelColor = Color(0xFF6e738d);
        break;
      case WheelColor.catMocha:
        wheelColor = Color(0xFF6c7086);
        break;
      case WheelColor.comfy:
        wheelColor = Color(0xFF101320);
        break;
      case WheelColor.iphGree:
        wheelColor = Color(0xFFdae1cd);
        break;
      case WheelColor.iphYell:
        wheelColor = Color(0xFFf8efc4);
        break;
      case WheelColor.nord:
        wheelColor = Color(0xFF4C566A);
        break;
      case WheelColor.mint:
        wheelColor = Color(0xFFd9e5e1);
        break;
      case WheelColor.yellow:
        wheelColor = Color(0xFFd4d4d6);
        break;
      default:
        wheelColor = Colors.white; // Provide a default color
        break;
    }

    switch (state.wheelColor) {
      case WheelColor.white:
        controlsColor = Color.fromARGB(255, 185, 185, 190);
        break;
      case WheelColor.black:
      case WheelColor.blueMetal:
      default:
        controlsColor = Color.fromARGB(255, 185, 185, 190); // Provide a default color
        break;
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onPanUpdate: panUpdateHandler,
            onPanStart: panStartHandler,
            child: Container(
              height: displayWidth(context) * 0.77,
              width: displayWidth(context) * 0.77,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Color.fromARGB(255, 95, 95, 95), width: 0.5),
                color: wheelColor,
              ),
              child: Stack(children: [
                menuButton(context),
                fastRewind(context),
                fastForward(context),
                playButton(context),
              ]),
            ),
          ),
          GestureDetector(
            onTap: () async {
              if (mainViewMode == MainViewMode.breakoutGame) {
                if (breakoutGame.currentState?.isBreakoutGameOver == true && breakoutGame.currentState?.gameState == Game.fail) {
                  breakoutGame.currentState?.restart();
                }
              } else if (popUp == true) {
                altMenuKey.currentState?.select();
              } else {
                menuKey.currentState?.select();
              }
              HapticFeedback.mediumImpact();
              await Future.delayed(Duration(milliseconds: 100));
              HapticFeedback.lightImpact();
            },
            child: selectButton(),
          ),
        ],
      ),
    );
  }

  AltSubMenu getAltMenu() {
    return AltSubMenu(
      items: [
        AltMenuItem(
          text: 'Spotify',
          onTap: () {
            BlocProvider.of<SongListBloc>(context).add(SpotifyConnected());
          },
        ),
        AltMenuItem(
          text: 'Apple Music',
          onTap: () {
            _showDialog(context);
          },
        ),
        AltMenuItem(
          text: 'Cancel',
          onTap: () => setState(() {
            popUp = false;
          }),
        ),
      ],
    );
  }

  IPodSubMenu getIPodMenu() {
    final IPodSubMenu themeMenu = IPodSubMenu(
      caption: MenuCaption(text: "Themes"),
      items: <IPodMenuItem>[
        IPodMenuItem(
          text: "3DS Red",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.red3ds));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.red3ds));
          },
        ),
        IPodMenuItem(
          text: "Arc Browser Pink",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.arcPink));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.white));
          },
        ),
        IPodMenuItem(
          text: "Catppuccin Latte",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.catLatt));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.catLatt));
          },
        ),
        IPodMenuItem(
          text: "Catppuccin Frappé",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.catFrap));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.catFrap));
          },
        ),
        IPodMenuItem(
          text: "Catppuccin Macchiato",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.catMacc));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.catMacc));
          },
        ),
        IPodMenuItem(
          text: "Catppuccin Mocha",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.catMocha));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.catMocha));
          },
        ),
        IPodMenuItem(
          text: "Comfy",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.comfy));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.comfy));
          },
        ),
        IPodMenuItem(
          text: "Desert Beige",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.beige));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.white));
          },
        ),
        IPodMenuItem(
          text: "iPhone Green",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.iphGree));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.iphGree));
          },
        ),
        IPodMenuItem(
          text: "iPhone Pink",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.pink));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.pink));
          },
        ),
        IPodMenuItem(
          text: "iPhone Yellow",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.iphYell));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.iphYell));
          },
        ),
         IPodMenuItem(
          text: "iPod Silver",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.silver));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.white));
          },
        ),
        IPodMenuItem(
          text: "iPod Space Gray",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.black));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.black));
          },
        ),
        IPodMenuItem(
          text: "Nord",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.nord));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.nord));
          },
        ),
        IPodMenuItem(
          text: "Oled Black",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.oledBlack));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.oledBlack));
          },
        ),
        IPodMenuItem(
          text: "Pixel Bay",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.bay));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.blueMetal));
          },
        ),
        IPodMenuItem(
          text: "Pixel Kinda Coral",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.coral));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.coral));
          },
        ),
        IPodMenuItem(
          text: "Pixel Mint",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.mint));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.mint));
          },
        ),
        IPodMenuItem(
          text: "Rabbit R1 Leuchtorange",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.orange));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.gray));
          },
        ),
        IPodMenuItem(
          text: "Switch Lite Yellow",
          onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.yellow));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.yellow));
          },
        ),
        IPodMenuItem(
          text: "Teenage Engineeringish",
        onTap: () {
            BlocProvider.of<ThemeBloc>(context).add(SkinThemeChanged(SkinTheme.teen));
            BlocProvider.of<ThemeBloc>(context).add(WheelColorChanged(WheelColor.gray));
          },
        ),
      ],
    );

    final IPodSubMenu songs = IPodSubMenu(
      caption: MenuCaption(text: "Songs"),
      items: <IPodMenuItem>[],
      itemsBuilder: _songListBuilder,
    );

    final IPodSubMenu likedSongsMenu = IPodSubMenu(
      caption: MenuCaption(text: "Liked Songs"),
      itemsBuilder: _likedSongsBuilder,
    );

    final IPodSubMenu playlistMenu = IPodSubMenu(
      caption: MenuCaption(text: "Playlists"),
      itemsBuilder: _playlistBuilder,
    );

    final IPodSubMenu extrasMenu = IPodSubMenu(
      caption: MenuCaption(text: "Extras"),
      items: <IPodMenuItem>[
        IPodMenuItem(
          text: "Breakout",
          onTap: () {
            showBreakoutGame();
            setState(() {
              isCoverCycleVisible = false;
            });
          },
        ),
      ],
    );

    final IPodSubMenu socialsMenu = IPodSubMenu(
      caption: MenuCaption(text: "About (V2.1.0)"),
      items: <IPodMenuItem>[
        IPodMenuItem(text: "Discord", onTap: _launchDiscord),
        IPodMenuItem(text: "X (Formerly Twitter)", onTap: _launchTwitter),
        IPodMenuItem(text: "Ko-Fi", onTap: _launchKofi),
        IPodMenuItem(text: "Github", onTap: _launchGithub),
      ],
    );

    final IPodSubMenu settingsMenu = IPodSubMenu(
      caption: MenuCaption(text: "Settings"),
      items: <IPodMenuItem>[
        IPodMenuItem(text: "Sign In", onTap: () => setState(() {
          popUp = true;
        })),
        IPodMenuItem(text: "Themes", subMenu: themeMenu),
        IPodMenuItem(
          text: "Open Onboarding", 
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => WalkthroughScreen()),
            );
          },
        ),
        IPodMenuItem(text: "About", subMenu: socialsMenu),
      ],
    );

    final IPodSubMenu menu = IPodSubMenu(
      caption: MenuCaption(text: "Retro"),
      items: <IPodMenuItem>[
        IPodMenuItem(
          text: "Now Playing",
          onTap: () {
            showPlayer();
            setState(() {
              isCoverCycleVisible = false;
            });
          },
        ),
        IPodMenuItem(
          text: "All Songs (Beta)",
          subMenu: songs,
          onTap: () => setState(() {
            isCoverCycleVisible = false;
          }),
        ),
        IPodMenuItem(
          text: "Liked Songs (Beta)",
          subMenu: likedSongsMenu,
          onTap: () => setState(() {
            isCoverCycleVisible = false;
          }),
        ),
        IPodMenuItem(
          text: "Playlists",
          subMenu: playlistMenu,
          onTap: () => setState(() {
            isCoverCycleVisible = false;
          }),
        ),
        IPodMenuItem(
          text: "Shuffle Songs (Beta)",
          onTap: () {
            //musicControls.shuffleSongs(context);
          },
        ),
        IPodMenuItem(
          text: "Extras",
          subMenu: extrasMenu,
        ),
        IPodMenuItem(
          text: "Settings",
          subMenu: settingsMenu,
        ),
      ],
    );

    return menu;
  }
}
