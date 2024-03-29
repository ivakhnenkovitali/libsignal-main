//
// Copyright 2020 Signal Messenger, LLC.
// SPDX-License-Identifier: AGPL-3.0-only
//

use crate::common::simple_types::*;
use crate::crypto;
use partial_default::PartialDefault;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, PartialDefault)]
pub struct AuthCredentialResponse {
    pub(crate) reserved: ReservedBytes,
    pub(crate) credential: crypto::credentials::AuthCredential,
    pub(crate) proof: crypto::proofs::AuthCredentialIssuanceProof,
}
