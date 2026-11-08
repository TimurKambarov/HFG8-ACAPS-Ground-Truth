// Starts the Flutter app. Replaces the default flutter_bootstrap.js that
// `flutter build web` / `flutter run -d edge` would otherwise generate; the
// {{...}} lines are filled in by Flutter at build time.
//
// The app is built for phones. index.html decides at load time how to show it:
//   * phone or narrow window -> full page, like any mobile web app;
//   * wide screen            -> inside a phone frame (the `gt-framed` class),
//                               so the app gets a phone-sized screen and lays
//                               itself out exactly as on a phone.
// In the frame Flutter runs in "embedded" mode: it draws into #gt-app instead
// of taking over the whole page.

{{flutter_js}}
{{flutter_build_config}}

(function () {
  var framed = document.documentElement.classList.contains('gt-framed');
  var host = framed ? document.getElementById('gt-app') : null;
  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      var appRunner = await engineInitializer.initializeEngine(host ? { hostElement: host } : {});
      await appRunner.runApp();
    },
  });
})();
