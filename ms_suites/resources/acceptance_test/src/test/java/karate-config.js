function fn() {
  var env = karate.env; // get java system property 'karate.env' in  build.gradle

  karate.log('karate.env system property was:', env);
  if (!env) {
    env = 'dev'; // a custom 'intelligent' default
  }
  var config = { // base config JSON
    defUrlBase: 'https://fua-int-qa.apps.ambientesbc.com/fua/sandbox/',
  };
  if (env == 'dev') {
    // over-ride only those that need to be
    config.defUrlBase = 'https://fua-int-dev.apps.ambientesbc.com/fua/sandbox/';
  } else if (env == 'cer') {
    config.defUrlBase = 'https://fua-int-qa.apps.ambientesbc.com/fua/sandbox/';
  }
  // don't waste time waiting for a connection or if servers don't respond within 5 seconds
  karate.configure('connectTimeout', 5000);
  karate.configure('readTimeout', 5000);
  return config;
}