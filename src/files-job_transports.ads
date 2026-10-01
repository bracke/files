with Ada.Finalization;
private with Interfaces.C;

with Files.Types;

--  Identity-bound ownership markers for private helper transport directories.
package Files.Job_Transports is
   --  A process-held ownership lease. The host releases it automatically after
   --  abnormal process termination, allowing a later startup to recognize an
   --  abandoned transport without guessing from its age.
   type Lease is limited private;

   --  Why an exclusive transport claim did or did not succeed.
   type Claim_Outcome is
     (Claim_Acquired,
      Claim_Busy,
      Claim_Deferred,
      Claim_Refused,
      Claim_Unrecoverable,
      Claim_Error);

   --  Create an owner-only transport directly under the host temporary
   --  directory. A pre-creation witness covers the interval before its
   --  identity-bound ownership marker is published.
   --  @param Directory Created transport directory.
   --  @param Identity Captured identity required by later cleanup.
   --  @param Owner Process-held lease guarding the transport while it is live.
   procedure Create
     (Directory : out Files.Types.UString;
      Identity  : out Files.Types.UString;
      Owner     : out Lease);

   --  Release this process's ownership lease before normal cleanup begins.
   --  @param Owner Lease returned by Create.
   procedure Release (Owner : in out Lease);

   --  True only while Owner holds the lease still found at this pathname and
   --  its current marker binds that lease to this same directory.
   --  @param Owner Lease to inspect.
   --  @param Directory Transport directory expected to be owned.
   --  @return True only for a held lease bound to the validated directory.
   function Holds (Owner : Lease; Directory : String) return Boolean;

   --  Join the creating process's shared lease before a helper touches its
   --  transport. If the parent crashed and recovery claimed first, fail
   --  closed; otherwise the helper keeps recovery out until it exits.
   --  @param Directory Published transport supplied by the parent.
   --  @param Owner Shared helper lease retained until the helper returns.
   --  @return True only when the current marker and lease still match.
   function Join_Helper (Directory : String; Owner : in out Lease) return Boolean;

   --  Publish a durable marker that prevents any new helper from joining,
   --  while still allowing a later exclusive recovery claim to finish removal.
   --  Must be called while holding the exclusive cleanup lease.
   --  @param Owner Exclusive claim for Directory.
   --  @param Directory Transport being retired.
   --  @return True when the retiring marker was published for this owner.
   function Retire (Owner : Lease; Directory : String) return Boolean;

   --  Read and validate a transport marker against the directory that contains it.
   --  @param Directory Possible transport directory.
   --  @return Its recorded identity, or an empty string when validation fails.
   function Recorded_Identity (Directory : String) return String;

   --  Distinguish an invalid or absent marker from a transient read failure.
   --  On failure, Identity is empty and Read_Error is True.
   --  @param Directory Possible transport directory.
   --  @param Identity Validated marker identity, or empty.
   --  @param Read_Error True when marker inspection failed for a retryable reason.
   procedure Inspect_Marker
     (Directory  : String;
      Identity   : out Files.Types.UString;
      Read_Error : out Boolean);

   --  Validate a transport against the identity retained by its creating process.
   --  @param Directory Possible transport directory.
   --  @param Expected_Identity Identity captured when the transport was created.
   --  @return True only for the same marked directory entry.
   function Matches (Directory, Expected_Identity : String) return Boolean;

   --  Atomically claim a validated abandoned transport and retain its lease
   --  until Owner is released. A development-format marker or a current
   --  marker without its lease cannot prove that an old owner has stopped.
   --  @param Directory Possible transport directory.
   --  @param Expected_Identity Identity read from its validated marker.
   --  @param Owner Exclusive claim, unchanged on failure.
   --  @return Claim_Acquired only while Owner exclusively holds this transport;
   --  Busy identifies a live claimant, Refused invalid input,
   --  Unrecoverable a valid marker without a safe ownership proof, and Error
   --  an operating-system failure that can be retried.
   function Claim_Abandoned
     (Directory, Expected_Identity : String;
      Owner : in out Lease) return Claim_Outcome;

   --  Claim an incomplete transport only when its pre-creation witness proves
   --  that this version started it and no creator still holds that witness.
   --  @param Directory Possible incomplete transport directory.
   --  @param Identity Captured identity for guarded removal, or empty when
   --  a pre-lease candidate has no filesystem birth time.
   --  @param Owner Exclusive claim, unchanged on failure.
   --  @param Minimum_Age Grace period before claiming a witnessed directory.
   --  @return Acquired retains the witness lock for guarded removal; Deferred
   --  means the creator is live or the grace period has not elapsed.
   function Claim_Incomplete
     (Directory   : String;
      Identity    : out Files.Types.UString;
      Owner       : in out Lease;
      Minimum_Age : Duration := 1.0) return Claim_Outcome;

   --  Release and remove the witness after its directory has been removed,
   --  or after a complete marker makes the witness unnecessary.
   --  @param Directory Transport whose witness is held.
   --  @param Owner Claimed witness, released by this call.
   procedure Forget_Witness (Directory : String; Owner : in out Lease);

   --  Remove an incomplete candidate that contains only protocol files.
   --  This works even when the filesystem has no birth time.
   --  @param Directory Witnessed incomplete transport to remove.
   --  @param Owner Exclusive witness claim held through removal.
   --  @return True when the incomplete directory was removed.
   function Remove_Empty_Incomplete (Directory : String; Owner : Lease) return Boolean;

   --  Remove orphaned witnesses whose directory is gone or fully marked.
   procedure Scavenge_Witnesses;

private
   type Lease is new Ada.Finalization.Limited_Controlled with record
      Handle : Interfaces.C.long_long := 0;
      Exclusive : Boolean := False;
      Directory : Files.Types.UString;
      Identity  : Files.Types.UString;
   end record;
   overriding procedure Finalize (Owner : in out Lease);
end Files.Job_Transports;
