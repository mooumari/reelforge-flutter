/// Every closed set of names a document may use.
///
/// These are the *names*, with nothing they map to. That separation is the
/// whole point of this package: validation needs to know that `easeOutCubic`
/// is a curve, and needs to know it without a Flutter engine, a widget
/// binding, or a `Curve` object anywhere in the process.
///
/// The Flutter side holds a table from each of these names to the value it
/// means, and `reelforge_json`'s vocabulary test asserts the two agree --
/// so a curve added to one and forgotten in the other fails in a second
/// rather than at render time.
library;

/// Curves a document may name.
///
/// A closed set on purpose. The alternative -- accepting four control points
/// -- lets a document express curves nobody wants and makes every one of them
/// look different in a diff; a name is the thing an editor can offer in a
/// dropdown and a reviewer can read.
const Set<String> curveNames = <String>{
  'linear',
  'ease',
  'easeIn',
  'easeOut',
  'easeInOut',
  'inQuad',
  'outQuad',
  'inOutQuad',
  'inCubic',
  'outCubic',
  'inOutCubic',
  'inQuart',
  'outQuart',
  'inOutQuart',
  'inExpo',
  'outExpo',
  'inOutExpo',
  'inCirc',
  'outCirc',
  'inBack',
  'outBack',
  'inOutBack',
  'outElastic',
  'outBounce',
};

/// Palette roles a colour may name instead of giving a hex triple.
///
/// The point of allowing these is that a document stays themeable: a template
/// written against `accent` follows whatever palette the app hands it, while
/// one written against `#4ADE80` is stuck being green.
const Set<String> paletteRoles = <String>{
  'background',
  'foreground',
  'muted',
  'accent',
  'warning',
  'surface',
  'outline',
};

/// The two palettes a document can start from.
const Set<String> paletteNames = <String>{'dark', 'light'};

const Set<String> alignmentNames = <String>{
  'topLeft',
  'topCenter',
  'topRight',
  'centerLeft',
  'center',
  'centerRight',
  'bottomLeft',
  'bottomCenter',
  'bottomRight',
};

const Set<String> fitNames = <String>{
  'cover',
  'contain',
  'fill',
  'fitWidth',
  'fitHeight',
  'none',
  'scaleDown',
};

const Set<String> mainAxisNames = <String>{
  'start',
  'end',
  'center',
  'spaceBetween',
  'spaceAround',
  'spaceEvenly',
};

const Set<String> crossAxisNames = <String>{
  'start',
  'end',
  'center',
  'stretch',
  'baseline',
};

/// The cross-axis values the kit's own components accept.
///
/// A shorter list than [crossAxisNames]: a `baseline` alignment needs a
/// baseline to align to, which a stat card does not have.
const Set<String> kitCrossAxisNames = <String>{
  'start',
  'end',
  'center',
  'stretch',
};

const Set<String> mainAxisSizeNames = <String>{'min', 'max'};

const Set<String> stackFitNames = <String>{'loose', 'expand', 'passthrough'};

const Set<String> fontWeightNames = <String>{
  'thin',
  'light',
  'regular',
  'medium',
  'semibold',
  'bold',
  'black',
};

const Set<String> textAlignNames = <String>{
  'left',
  'right',
  'center',
  'justify',
  'start',
  'end',
};

const Set<String> axisNames = <String>{'horizontal', 'vertical'};

/// The named sizes a `text` node and a theme can ask for.
///
/// Naming a role rather than a number is what keeps a document readable at two
/// resolutions: `headline` follows the theme's scale, `58` does not.
const Set<String> textRoles = <String>{
  'display',
  'headline',
  'title',
  'body',
  'label',
  'caption',
  'statistic',
};

/// The animation shapes an `enter` node can name.
const Set<String> enterModes = <String>{
  'fade',
  'scale',
  'spring',
  'slideUp',
  'slideDown',
  'slideLeft',
  'slideRight',
};

const Set<String> transitionNames = <String>{'none', 'fade', 'slide', 'scale'};

const Set<String> sequenceLayoutNames = <String>{'none', 'fill'};
