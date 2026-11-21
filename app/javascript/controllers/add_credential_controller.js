import { Controller } from "@hotwired/stimulus"
import * as Credential from "credential";

export default class extends Controller {
  create(event) {
    var [data, status, xhr] = event.detail;
    var credentialOptions = data;

    Credential.create("/credentials/callback", credentialOptions);
  }
}
