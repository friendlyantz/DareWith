import { Turbo } from "@hotwired/turbo-rails";
import { showMessage } from "messenger";

function getCSRFToken() {
  var CSRFSelector = document.querySelector('meta[name="csrf-token"]')
  if (CSRFSelector) {
    return CSRFSelector.getAttribute("content")
  } else {
    return null
  }
}

// Resolves false when sign-in didn't go through, so the caller can let the person try again
function callback(url, body) {
  return fetch(url, {
    method: "POST",
    body: JSON.stringify(body),
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": getCSRFToken()
    },
    credentials: 'same-origin'
  }).then(function(response) {
    if (response.ok) {
      response.json()
        .then((data) => Turbo.visit(data.redirect_to || "/", { action: "replace" }))
        .catch(() => Turbo.visit("/", { action: "replace" }))
      return true;
    } else if (response.status < 500) {
      response.text().then(showMessage);
    } else {
      showMessage("Sorry, something wrong happened.");
    }
    return false;
  }).catch(() => {
    showMessage("Sorry, something wrong happened.");
    return false;
  });
}

async function create(callbackUrl, credentialOptions) {
  console.log("Creating new public key credential...");
  
  try {
    // Use native browser API to parse JSON options
    const publicKey = PublicKeyCredential.parseCreationOptionsFromJSON(credentialOptions);
    const credential = await navigator.credentials.create({ publicKey });
    
    // Use native toJSON() to serialize the credential
    return await callback(callbackUrl, credential.toJSON());
  } catch (error) {
    console.error("WebAuthn create error:", error);
    showMessage(`${error.name}: ${error.message}`);
    return false;
  }
}

async function get(credentialOptions) {
  console.log("Getting public key credential...");
  
  try {
    // Use native browser API to parse JSON options
    const publicKey = PublicKeyCredential.parseRequestOptionsFromJSON(credentialOptions);
    const credential = await navigator.credentials.get({ publicKey });
    
    // Use native toJSON() to serialize the credential
    return await callback("/webauthn/session/callback", credential.toJSON());
  } catch (error) {
    console.error("WebAuthn get error:", error);
    showMessage(`${error.name}: ${error.message}`);
    return false;
  }
}

// Check if native WebAuthn JSON methods are supported
function supported() {
  return !!window.PublicKeyCredential?.parseCreationOptionsFromJSON;
}

export { create, get, supported }
