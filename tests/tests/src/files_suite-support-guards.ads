with Ada.Finalization;

with Files.Model;
with Files.Process_Jobs;
with Files.Types;

--  Guards that put process-wide state back when a test leaves scope, on an
--  assertion failure too: environment variables, shortcut overrides, the
--  working directory, a paste execution, job transports.
package Files_Suite.Support.Guards is

   --  Restores the environment variables it saved when it leaves scope,
   --  whether the test passed or an assertion raised, so a failing test
   --  cannot leave HOME or TMPDIR pointing into its fixtures.
   type Environment_Guard is new Ada.Finalization.Limited_Controlled with private;

   --  Remember Name's current value (or that it is unset) for restoring.
   --
   --  @param Guard Guard that restores it.
   --  @param Name Environment variable name.
   procedure Save (Guard : in out Environment_Guard; Name : String);

   --  Put every saved variable back as it was.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Environment_Guard);

   --  Clears every global shortcut override (Files.Commands) when it leaves
   --  scope, whether the test passed or an assertion raised, so a failing
   --  shortcut test cannot leave its bindings in force for the rest of the
   --  suite. Declaring one does not clear anything; a test that needs a clean
   --  start still calls Files.Commands.Reset_Shortcut_Overrides first.
   type Shortcut_Guard is new Ada.Finalization.Limited_Controlled with null record;

   --  Clear every shortcut override.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Shortcut_Guard);

   --  Puts the working directory back to what it was when the guard was
   --  declared, when it leaves scope -- on an assertion failure too -- so a
   --  test that changes directory cannot leave the rest of the suite running
   --  somewhere else. A restore that fails is reported on standard error
   --  (a finalizer must not raise); the test that owned the guard is not
   --  failed by it.
   type Directory_Guard is new Ada.Finalization.Limited_Controlled with private;

   --  Remember the current working directory.
   --
   --  @param Guard Guard being declared.
   overriding procedure Initialize (Guard : in out Directory_Guard);

   --  Change back to the remembered working directory.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Directory_Guard);

   --  @param Guard A guard.
   --  @return The working directory Guard restores.
   function Saved_Directory (Guard : Directory_Guard) return String;

   --  Ends Model's paste execution and cancels its background refresh when
   --  it leaves scope -- on an assertion failure too -- so a failing test
   --  cannot leave a helper writing into the next one's fixtures. Release
   --  does the same at once, for a test that must end them before the rest
   --  of its cleanup; doing it twice is harmless. A cleanup that fails is
   --  reported on standard error (a finalizer must not raise).
   type Paste_Guard (Model : not null access Files.Model.Window_Model) is
     new Ada.Finalization.Limited_Controlled with null record;

   --  End the paste execution and the background refresh now.
   --
   --  @param Guard Guard whose model to clean up.
   procedure Release (Guard : in out Paste_Guard);

   --  End the paste execution and the background refresh.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Paste_Guard);

   --  Delete the transport directory Path, a test's fixture, when it is set
   --  and exists.
   --
   --  @param Path Transport directory to delete; empty for none.
   procedure Remove_Transport_Fixture (Path : Files.Types.UString);

   --  Resets the test's job Session and deletes the transport fixtures it
   --  was told about (Remove_Transport_Fixture) when it leaves scope -- on
   --  an assertion failure too -- so a failing test cannot leave a live job
   --  or a stray transport behind for the next one. Release does the same
   --  at once, for a test that must restore before the rest of its work;
   --  doing it twice is harmless. A restore that fails is reported on
   --  standard error (a finalizer must not raise).
   type Process_Jobs_Guard (Session : not null access Files.Process_Jobs.Session) is
     new Ada.Finalization.Limited_Controlled with private;

   --  Have Guard delete Path, a transport fixture, when it restores.
   --
   --  @param Guard Guard to tell.
   --  @param Path Transport directory to delete; empty for none.
   procedure Track (Guard : in out Process_Jobs_Guard; Path : Files.Types.UString);

   --  Reset the session and delete the tracked fixtures now.
   --
   --  @param Guard Guard whose session and fixtures to restore.
   procedure Release (Guard : in out Process_Jobs_Guard);

   --  Reset the session and delete the tracked fixtures.
   --
   --  @param Guard Guard leaving scope.
   overriding procedure Finalize (Guard : in out Process_Jobs_Guard);

private

   type Saved_Variable is record
      Name  : Files.Types.UString;
      Value : Files.Types.UString;
      Was   : Boolean := False;
   end record;

   type Saved_Variables is array (1 .. 8) of Saved_Variable;

   type Environment_Guard is new Ada.Finalization.Limited_Controlled with record
      Count : Natural := 0;
      Saved : Saved_Variables;
   end record;

   type Directory_Guard is new Ada.Finalization.Limited_Controlled with record
      Saved : Files.Types.UString;
   end record;

   type Process_Jobs_Guard (Session : not null access Files.Process_Jobs.Session) is
     new Ada.Finalization.Limited_Controlled with record
      Fixtures : Files.Types.String_Vectors.Vector;
   end record;

end Files_Suite.Support.Guards;
