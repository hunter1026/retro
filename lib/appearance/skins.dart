import 'package:retro/blocs/theme/theme.dart';

String retroSkin = "assets/skins/theme1.png";
String silverSkin = "assets/skins/silver-theme.png";
String blackSkin = "assets/skins/black-theme.png";
String carbonFiberSkin = "assets/skins/carbonfiber-theme.png";
String gen7SilverSkin = "assets/skins/gen7_silver.png";
String gen7BlackSkin = "assets/skins/gen7_black.png";
String customBeigeSkin = "assets/skins/custom_beige.png"; // Add this line

String getSkin(ThemeState state) {
  switch (state.skinTheme) {
    case SkinTheme.black:
      return gen7BlackSkin;
    case SkinTheme.silver:
      return gen7SilverSkin;
    case SkinTheme.retro:
      return retroSkin;
    case SkinTheme.carbonfiber:
      return carbonFiberSkin;
    case SkinTheme.beige: // Add this case
      return customBeigeSkin;
    default:
      return gen7BlackSkin;
  }
}
