import {initializeApp} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-app.js";
import {
  GoogleAuthProvider,
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-auth.js";
import {
  ReCaptchaEnterpriseProvider,
  getToken,
  initializeAppCheck,
} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-app-check.js";
import {getFunctions, httpsCallable} from "https://www.gstatic.com/firebasejs/11.10.0/firebase-functions.js";

const config = window.VENDING_NAVI_DELETE_ACCOUNT_CONFIG;
const setupError = document.querySelector("#setup-error");
const status = document.querySelector("#status");
const signedOut = document.querySelector("#signed-out");
const signedIn = document.querySelector("#signed-in");
const signedInAs = document.querySelector("#signed-in-as");
const emailSignInForm = document.querySelector("#email-sign-in-form");
const googleSignInButton = document.querySelector("#google-sign-in");
const deleteAccountButton = document.querySelector("#delete-account");
const signOutButton = document.querySelector("#sign-out");

function showStatus(message, type = "") {
  status.textContent = message;
  status.className = `notice ${type}`.trim();
}

function setBusy(button, busy) {
  button.disabled = busy;
}

function showSetupError(message) {
  setupError.textContent = message;
  setupError.classList.remove("hidden");
  document.querySelectorAll("button, input").forEach((element) => {
    element.disabled = true;
  });
}

function hasRequiredConfiguration(value) {
  return value &&
    value.firebase &&
    value.firebase.apiKey &&
    value.firebase.authDomain &&
    value.firebase.projectId &&
    value.firebase.appId &&
    value.appCheckSiteKey &&
    !Object.values(value.firebase).some((entry) => String(entry).startsWith("REPLACE_")) &&
    !String(value.appCheckSiteKey).startsWith("REPLACE_");
}

if (!hasRequiredConfiguration(config)) {
  showSetupError("この削除ページは現在準備中です。設定が完了するまで削除操作は利用できません。");
} else {
  const app = initializeApp(config.firebase);
  const appCheck = initializeAppCheck(app, {
    provider: new ReCaptchaEnterpriseProvider(config.appCheckSiteKey),
    isTokenAutoRefreshEnabled: true,
  });
  const auth = getAuth(app);
  const deleteAccount = httpsCallable(getFunctions(app), "deleteAccount");

  onAuthStateChanged(auth, (user) => {
    signedOut.classList.toggle("hidden", user !== null);
    signedIn.classList.toggle("hidden", user === null);
    status.classList.add("hidden");
    if (user) {
      signedInAs.textContent = `ログイン中: ${user.email ?? "メールアドレス未設定のアカウント"}`;
    }
  });

  emailSignInForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = document.querySelector("#email").value;
    const password = document.querySelector("#password").value;
    const submitButton = emailSignInForm.querySelector("button");
    setBusy(submitButton, true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch {
      showStatus("ログインできませんでした。メールアドレスとパスワードを確認してください。", "error");
    } finally {
      setBusy(submitButton, false);
    }
  });

  googleSignInButton.addEventListener("click", async () => {
    setBusy(googleSignInButton, true);
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } catch {
      showStatus("Googleでログインできませんでした。ポップアップの許可とアカウントを確認してください。", "error");
    } finally {
      setBusy(googleSignInButton, false);
    }
  });

  signOutButton.addEventListener("click", () => signOut(auth));

  deleteAccountButton.addEventListener("click", async () => {
    if (!window.confirm("このアカウントを完全に削除します。取り消すことはできません。")) {
      return;
    }

    setBusy(deleteAccountButton, true);
    try {
      // Obtain an App Check token before the call. Production Functions reject
      // this request if the web App Check integration is not active.
      await getToken(appCheck, true);
      await deleteAccount({confirmation: "DELETE_ACCOUNT"});
      showStatus("アカウントを削除しました。", "success");
    } catch (error) {
      const code = typeof error?.code === "string" ? error.code : "";
      if (code === "functions/failed-precondition") {
        showStatus("本人確認の有効期限が切れています。いったんログアウトして、もう一度ログインしてください。", "error");
      } else if (code === "functions/unauthenticated") {
        showStatus("ログイン状態を確認できませんでした。もう一度ログインしてください。", "error");
      } else {
        showStatus("削除を完了できませんでした。時間をおいて再試行してください。", "error");
      }
    } finally {
      setBusy(deleteAccountButton, false);
    }
  });
}
