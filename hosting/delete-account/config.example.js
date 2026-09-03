// Copy this file to config.js before a Hosting deployment.
// Firebase web configuration is public client configuration, not a secret.
// Do not add service-account credentials or server secrets here.
window.VENDING_NAVI_DELETE_ACCOUNT_CONFIG = {
  firebase: {
    apiKey: "REPLACE_WITH_FIREBASE_WEB_API_KEY",
    authDomain: "REPLACE_WITH_FIREBASE_WEB_AUTH_DOMAIN",
    projectId: "vendingnavi",
    appId: "REPLACE_WITH_FIREBASE_WEB_APP_ID",
  },
  // Firebase App Check's reCAPTCHA Enterprise site key for this web app.
  // Keep this unset until App Check is registered in Firebase Console.
  appCheckSiteKey: "REPLACE_WITH_RECAPTCHA_ENTERPRISE_SITE_KEY",
};
