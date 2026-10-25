with Ada.Finalization;
with Ada.Strings.Unbounded;

--  A second filesystem for the tests that move across devices.
--
--  A cross-device move only takes the copy-then-remove path when its two ends
--  really are on different devices; on one device it is a plain rename, and a
--  test that meant to prove the copy path would pass having proved nothing.
--  So the other end is chosen by comparing device ids with the suite's scratch
--  root, never by assuming that a given path is a separate mount.
package Files_Suite.Volumes is

   --  The reason a test skips when Other_Volume is "".
   No_Other_Volume : constant String :=
     "no writable directory on a device other than the test root's"
     & " (set FILES_TEST_OTHER_VOLUME; /dev/shm is tried on Linux)";

   --  A writable directory on a different device than Files_Suite.Support.Root.
   --
   --  Tried in order: the directory FILES_TEST_OTHER_VOLUME names (CI mounts a
   --  RAM disk or a VHD for it), then /dev/shm on Linux. A candidate counts only
   --  when it is a directory, both device ids are known and differ, and a
   --  directory can be made in it. The answer is worked out once per run.
   --
   --  @return The directory, or "" when no candidate qualifies here.
   function Other_Volume return String;

   --  A fresh directory on Other_Volume, removed with everything in it when the
   --  object leaves scope, whether the test passed or an assertion raised.
   type Remote_Directory is new Ada.Finalization.Limited_Controlled with private;

   --  Make the directory, removing any one this object made before.
   --
   --  @param Directory Object that owns it.
   --  @param Prefix Readable leading part of its name.
   procedure Create (Directory : in out Remote_Directory; Prefix : String);

   --  Where the directory is.
   --
   --  @param Directory Object that owns it.
   --  @return The directory's path, or "" when there is no other volume or it
   --    could not be made there.
   function Path (Directory : Remote_Directory) return String;

   --  Remove the directory tree.
   --
   --  @param Directory Object leaving scope.
   overriding procedure Finalize (Directory : in out Remote_Directory);

private

   type Remote_Directory is new Ada.Finalization.Limited_Controlled with record
      Location : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Files_Suite.Volumes;
