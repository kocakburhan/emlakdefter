You can use Firebase Authentication to sign in a user by sending an SMS message
to the user's phone. The user signs in using a one-time code contained in the
SMS message.

The easiest way to add phone number sign-in to your app is to use
[FirebaseUI](https://github.com/firebase/firebaseui-web/),
which includes a drop-in sign-in widget that implements sign-in flows for phone
number sign-in, as well as password-based and federated sign-in. This document
describes how to implement a phone number sign-in flow using the Firebase SDK.
Phone numbers that end users provide for authentication will be sent and stored by Google to improve our spam and abuse prevention across Google services, including but not limited to Firebase. Developers should ensure they have appropriate end-user consent prior to using the Firebase Authentication phone number sign-in service.

## Before you begin

If you haven't already, copy the initialization snippet from the [Firebase console](https://console.firebase.google.com/) to your project as described in [Add Firebase to your JavaScript project](https://firebase.google.com/docs/web/setup).

### Security concerns

Authentication using only a phone number, while convenient, is less secure
than the other available methods, because possession of a phone number
can be easily transferred between users. Also, on devices with multiple user
profiles, any user that can receive SMS messages can sign in to an account using
the device's phone number.

If you use phone number based sign-in in your app, you should offer it
alongside more secure sign-in methods, and inform users of the security
tradeoffs of using phone number sign-in.

## Enable Phone Number sign-in for your Firebase project

To sign in users by SMS, you must first enable the Phone Number sign-in
method for your Firebase project:

1. In the [Firebase console](https://console.firebase.google.com/), open the **Authentication** section.
2. On the **Sign-in Method** page, enable the **Phone Number** sign-in method.
3. On the **Settings** page, set a policy on the regions to which you want to allow or deny SMS messages to be sent. For new projects, the default policy allows no regions.
4. On the same page, if the domain that will host your app isn't listed in the **OAuth redirect domains** section, add your domain. Note that localhost is not allowed as a hosted domain for the purposes of phone auth.

## Set up the reCAPTCHA verifier

Before you can sign in users with their phone numbers, you must set up
Firebase's reCAPTCHA verifier. Firebase uses reCAPTCHA to prevent abuse, such as
by ensuring that the phone number verification request comes from one of your
app's allowed domains.

You don't need to manually set up a reCAPTCHA client; when you use the
Firebase SDK's `RecaptchaVerifier` object, Firebase automatically
creates and handles any necessary client keys and secrets.

The `RecaptchaVerifier` object supports
[invisible
reCAPTCHA](https://www.google.com/recaptcha/intro/invisible.html), which can often verify the user without requiring any user
action, as well as the reCAPTCHA widget, which always requires user interaction
to complete successfully.

The underlying rendered reCAPTCHA can be localized to the user's preference by updating the
language code on the Auth instance before rendering the reCAPTCHA. The aforementioned localization
will also apply to the SMS message sent to the user, containing the verification code.

### Web

```javascript
import { getAuth } from "firebase/auth";

const auth = getAuth();
auth.languageCode = 'it';
// To apply the default browser preference instead of explicitly setting it.
// auth.useDeviceLanguage();https://github.com/firebase/snippets-web/blob/95c8c159ff4d90af442352f058406f1aeb8adcbb/snippets/auth-next/index/auth_set_language_code.js#L8-L13
```

### Web

```javascript
firebase.auth().languageCode = 'it';
// To apply the default browser preference instead of explicitly setting it.
// firebase.auth().useDeviceLanguage();https://github.com/firebase/snippets-web/blob/95c8c159ff4d90af442352f058406f1aeb8adcbb/auth/index.js#L73-L75
```

### Use invisible reCAPTCHA

To use an invisible reCAPTCHA, create a `RecaptchaVerifier` object
with the `size` parameter set to `invisible`, specifying
the ID of the button that submits your sign-in form. For example:

### Web

```javascript
import { getAuth, RecaptchaVerifier } from "firebase/auth";

const auth = getAuth();
window.recaptchaVerifier = new RecaptchaVerifier(auth, 'sign-in-button', {
  'size': 'invisible',
  'callback': (response) => {
    // reCAPTCHA solved, allow signInWithPhoneNumber.
    onSignInSubmit();
  }
});
```

### Web

```javascript
window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('sign-in-button', {
  'size': 'invisible',
  'callback': (response) => {
    // reCAPTCHA solved, allow signInWithPhoneNumber.
    onSignInSubmit();
  }
});
```

### Use the reCAPTCHA widget

To use the visible reCAPTCHA widget, create an element on your page to
contain the widget, and then create a `RecaptchaVerifier` object,
specifying the ID of the container when you do so. For example:

### Web

```javascript
import { getAuth, RecaptchaVerifier } from "firebase/auth";

const auth = getAuth();
window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {});
```

### Web

```javascript
window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('recaptcha-container');
```

#### Optional: Specify reCAPTCHA parameters

You can optionally set callback functions on the
`RecaptchaVerifier` object that are called when the user solves the
reCAPTCHA or the reCAPTCHA expires before the user submits the form:

### Web

```javascript
import { getAuth, RecaptchaVerifier } from "firebase/auth";

const auth = getAuth();
window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
  'size': 'normal',
  'callback': (response) => {
    // reCAPTCHA solved, allow signInWithPhoneNumber.
    // ...
  },
  'expired-callback': () => {
    // Response expired. Ask user to solve reCAPTCHA again.
    // ...
  }
});
```

### Web

```javascript
window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('recaptcha-container', {
  'size': 'normal',
  'callback': (response) => {
    // reCAPTCHA solved, allow signInWithPhoneNumber.
    // ...
  },
  'expired-callback': () => {
    // Response expired. Ask user to solve reCAPTCHA again.
    // ...
  }
});
```

#### Optional: Pre-render the reCAPTCHA

If you want to pre-render the reCAPTCHA before you submit a sign-in request,
call `render`:

### Web

```javascript
recaptchaVerifier.render().then((widgetId) => {
  window.recaptchaWidgetId = widgetId;
});
```

### Web

```javascript
recaptchaVerifier.render().then((widgetId) => {
  window.recaptchaWidgetId = widgetId;
});
```

After `render` resolves, you get the reCAPTCHA's widget ID, which
you can use to make calls to the
[reCAPTCHA](https://developers.google.com/recaptcha/intro) API:

### Web

```javascript
const recaptchaResponse = grecaptcha.getResponse(recaptchaWidgetId);
```

### Web

```javascript
const recaptchaResponse = grecaptcha.getResponse(recaptchaWidgetId);
```

## Send a verification code to the user's phone

To initiate phone number sign-in, present the user an interface that prompts
them to provide their phone number, and then call
`signInWithPhoneNumber` to request that Firebase send an
authentication code to the user's phone by SMS:

1. Get the user's phone number.

   Legal requirements vary, but as a best practice
   and to set expectations for your users, you should inform them that if they use
   phone sign-in, they might receive an SMS message for verification and standard
   rates apply.
2. Call `signInWithPhoneNumber`, passing to it the user's phone number and the `RecaptchaVerifier` you created earlier.

   ### Web

   ```javascript
   import { getAuth, signInWithPhoneNumber } from "firebase/auth";

   const phoneNumber = getPhoneNumberFromUserInput();
   const appVerifier = window.recaptchaVerifier;

   const auth = getAuth();
   signInWithPhoneNumber(auth, phoneNumber, appVerifier)
       .then((confirmationResult) => {
         // SMS sent. Prompt user to type the code from the message, then sign the
         // user in with confirmationResult.confirm(code).
         window.confirmationResult = confirmationResult;
         // ...
       }).catch((error) => {
         // Error; SMS not sent
         // ...
       });
   ```

   ### Web

   ```javascript
   const phoneNumber = getPhoneNumberFromUserInput();
   const appVerifier = window.recaptchaVerifier;
   firebase.auth().signInWithPhoneNumber(phoneNumber, appVerifier)
       .then((confirmationResult) => {
         // SMS sent. Prompt user to type the code from the message, then sign the
         // user in with confirmationResult.confirm(code).
         window.confirmationResult = confirmationResult;
         // ...
       }).catch((error) => {
         // Error; SMS not sent
         // ...
       });
   ```
   If `signInWithPhoneNumber` results in an error, reset the reCAPTCHA so the user can try again:

   ```
   grecaptcha.reset(window.recaptchaWidgetId);

   // Or, if you haven't stored the widget ID:
   window.recaptchaVerifier.render().then(function(widgetId) {
     grecaptcha.reset(widgetId);
   });
   ```

   > [!NOTE]
   > **Note:** See [Firebase Authentication
   > Limits](https://firebase.google.com/docs/auth/limits#phone-auth) for applicable usage limits and quotas.

The `signInWithPhoneNumber` method issues the reCAPTCHA challenge
to the user, and if the user passes the challenge, requests that
Firebase Authentication send an SMS message containing a verification code to the
user's phone.

> [!NOTE]
> To prevent abuse, Firebase enforces a limit on the number of SMS messages that can be sent to a single phone number within a period of time. If you exceed this limit, phone number verification requests might be throttled. If you encounter this issue during development, use a different phone number for testing, or try the request again later.

## Sign in the user with the verification code

After the call to `signInWithPhoneNumber` succeeds, prompt the
user to type the verification code they received by SMS. Then, sign in the user
by passing the code to the `confirm` method of the
`ConfirmationResult` object that was passed to
`signInWithPhoneNumber`'s fulfillment handler (that is, its
`then` block). For example:

### Web

```javascript
const code = getCodeFromUserInput();
confirmationResult.confirm(code).then((result) => {
  // User signed in successfully.
  const user = result.user;
  // ...
}).catch((error) => {
  // User couldn't sign in (bad verification code?)
  // ...
});
```

### Web

```javascript
const code = getCodeFromUserInput();
confirmationResult.confirm(code).then((result) => {
  // User signed in successfully.
  const user = result.user;
  // ...
}).catch((error) => {
  // User couldn't sign in (bad verification code?)
  // ...
});
```

If the call to `confirm` succeeded, the user is successfully
signed in.

#### Get the intermediate AuthCredential object

If you need to get an `AuthCredential` object for the user's
account, pass the verification code from the confirmation result and the
verification code to `PhoneAuthProvider.credential` instead of
calling `confirm`:

```
var credential = firebase.auth.PhoneAuthProvider.credential(confirmationResult.verificationId, code);
```

Then, you can sign in the user with the credential:

```
firebase.auth().signInWithCredential(credential);
```

## Test with fictional phone numbers

You can set up fictional phone numbers for development via the Firebase console. Testing with fictional phone
numbers provides these benefits:

- Test phone number authentication without consuming your usage quota.
- Test phone number authentication without sending an actual SMS message.
- Run consecutive tests with the same phone number without getting throttled. This minimizes the risk of rejection during App store review process if the reviewer happens to use the same phone number for testing.
- Test readily in development environments without any additional effort, such as the ability to develop in an iOS simulator or an Android emulator without Google Play Services.
- Write integration tests without being blocked by security checks normally applied on real phone numbers in a production environment.


Fictional phone numbers must meet these requirements:

1. Make sure you use phone numbers that are indeed fictional, and do not already exist. Firebase Authentication does not allow you to set existing phone numbers used by real users as test numbers. One option is to use 555 prefixed numbers as US test phone numbers, for example: *+1 650-555-3434*
2. Phone numbers have to be correctly formatted for length and other constraints. They will still go through the same validation as a real user's phone number.
3. You can add up to 10 phone numbers for development.
4. Use test phone numbers/codes that are hard to guess and change those frequently.

### Create fictional phone numbers and verification codes

1. In the [Firebase console](https://console.firebase.google.com/), open the **Authentication** section.
2. In the **Sign in method** tab, enable the Phone provider if you haven't already.
3. Open the **Phone numbers for testing** accordion menu.
4. Provide the phone number you want to test, for example: *+1 650-555-3434*.
5. Provide the 6-digit verification code for that specific number, for example: *654321*.
6. **Add** the number. If there's a need, you can delete the phone number and its code by hovering over the corresponding row and clicking the trash icon.

### Manual testing

You can directly start using a fictional phone number in your application. This allows you to
perform manual testing during development stages without running into quota issues or throttling.
You can also test directly from an iOS simulator or Android emulator without Google Play Services
installed.

When you provide the fictional phone number and send the verification code, no actual SMS is
sent. Instead, you need to provide the previously configured verification code to complete the sign
in.

On sign-in completion, a Firebase user is created with that phone number. The
user has the same behavior and properties as a real phone number user, and can access
Realtime Database/Cloud Firestore and other services the same way. The ID token minted during
this process has the same signature as a real phone number user.

> [!CAUTION]
> Because the ID token for the fictional phone number has the same signature as a real phone number user, it is important to store these numbers securely and to continuously recycle them.

Another option is to [set a test role via custom
claims](https://firebase.google.com/docs/auth/admin/custom-claims) on these users to differentiate them as fake users if you want to further restrict
access.

### Integration testing

In addition to manual testing, Firebase Authentication provides APIs to help write integration tests
for phone auth testing. These APIs disable app verification by disabling the reCAPTCHA
requirement in web and silent push notifications in iOS. This makes automation testing possible in
these flows and easier to implement. In addition, they help provide the ability to test instant
verification flows on Android.

> [!NOTE]
> Make sure app verification is not disabled for production apps and that no fictional phone numbers are hardcoded in your production app.

On web, set `appVerificationDisabledForTesting` to
`true` before rendering the `firebase.auth.RecaptchaVerifier`. This resolves
the reCAPTCHA automatically, allowing you to pass the phone number without manually solving it. Note
that even though reCAPTCHA is disabled, using a non-fictional phone number will still fail to
complete sign in. Only fictional phone numbers can be used with this API.

```
// Turn off phone auth app verification.
firebase.auth().settings.appVerificationDisabledForTesting = true;

var phoneNumber = "+16505554567";
var testVerificationCode = "123456";

// This will render a fake reCAPTCHA as appVerificationDisabledForTesting is true.
// This will resolve after rendering without app verification.
var appVerifier = new firebase.auth.RecaptchaVerifier('recaptcha-container');
// signInWithPhoneNumber will call appVerifier.verify() which will resolve with a fake
// reCAPTCHA response.
firebase.auth().signInWithPhoneNumber(phoneNumber, appVerifier)
    .then(function (confirmationResult) {
      // confirmationResult can resolve with the fictional testVerificationCode above.
      return confirmationResult.confirm(testVerificationCode)
    }).catch(function (error) {
      // Error; SMS not sent
      // ...
    });
```


Visible and invisible mock reCAPTCHA app verifiers behave differently when app verification is
disabled:

- **Visible reCAPTCHA** : When the visible reCAPTCHA is rendered via `appVerifier.render()`, it automatically resolves itself after a fraction of a second delay. This is equivalent to a user clicking the reCAPTCHA immediately upon rendering. The reCAPTCHA response will expire after some time and then auto-resolve again.
- **Invisible reCAPTCHA** : The invisible reCAPTCHA does not auto-resolve on rendering and instead does so on the `appVerifier.verify()`call or when the button anchor of the reCAPTCHA is clicked after a fraction of a second delay. Similarly, the response will expire after some time and will only auto-resolve either after the `appVerifier.verify()` call or when the button anchor of the reCAPTCHA is clicked again.


Whenever a mock reCAPTCHA is resolved, the corresponding callback function is triggered as expected
with the fake response. If an expiration callback is also specified, it will trigger on expiration.

## Next steps

After a user signs in for the first time, a new user account is created and
linked to the credentials---that is, the user name and password, phone
number, or auth provider information---the user signed in with. This new
account is stored as part of your Firebase project, and can be used to identify
a user across every app in your project, regardless of how the user signs in.

- In your apps, the recommended way to know the auth status of your user is to
  set an observer on the `Auth` object. You can then get the user's
  basic profile information from the `User` object. See
  [Manage Users](https://firebase.google.com/docs/auth/web/manage-users).

- In your Firebase Realtime Database and Cloud Storage
  [Security Rules](https://firebase.google.com/docs/database/security/user-security), you can
  get the signed-in user's unique user ID from the `auth` variable,
  and use it to control what data a user can access.

You can allow users to sign in to your app using multiple authentication
providers by [linking auth provider credentials to an
existing user account.](https://firebase.google.com/docs/auth/web/account-linking)

To sign out a user, call [`signOut`](https://firebase.google.com/docs/reference/js/auth#signout):

### Web

```javascript
import { getAuth, signOut } from "firebase/auth";

const auth = getAuth();
signOut(auth).then(() => {
  // Sign-out successful.
}).catch((error) => {
  // An error happened.
});
```

### Web

```javascript
firebase.auth().signOut().then(() => {
  // Sign-out successful.
}).catch((error) => {
  // An error happened.
});
```