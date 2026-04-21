import 'package:flute_example/widgets/mp_inherited.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'safe_artwork_widget.dart';

class MPDrawer extends StatefulWidget {
  const MPDrawer({super.key});

  @override
  MPDrawerState createState() {
    return MPDrawerState();
  }
}

class MPDrawerState extends State<MPDrawer> {
  @override
  Widget build(BuildContext context) {
    var rootIW = MPInheritedWidget.of(context).songData;
    var cI = rootIW.currentIndex;
    if (rootIW.songs.isEmpty) {
      return const Drawer(
        child: SizedBox.shrink(),
      );
    }
    final song = rootIW.songs[(cI < 0) ? 0 : rootIW.currentIndex];
    return Drawer(
        child: ListView(
      children: <Widget>[
        DrawerHeader(
          padding: EdgeInsets.zero,
          child: SafeArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            artworkFit: BoxFit.fill,
            nullArtworkWidget: Image.asset(
              "assets/music_record.jpeg",
              fit: BoxFit.fill,
              scale: 5.0,
            ),
          ),
        ),
        // new SwitchListTile(
        //   title: new Text("Dark Theme"),
        //   value: dark,
        //   onChanged: (bool value) {
        //     preferences.setBool("dark", value);
        //     Scaffold.of(context).showSnackBar(new SnackBar(
        //           content: new Text("Please restart to perform changes."),
        //         ));
        //     Navigator.pop(context);
        //   },
        // ),
      ],
    ));
  }
}
