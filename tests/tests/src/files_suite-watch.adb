with Ada.Directories;
with Ada.Text_IO;

with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases;

with Files.Platform.Watch;

package body Files_Suite.Watch is

   use Files.Platform.Watch;

   type Watch_Test_Case is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   function Name (T : Watch_Test_Case) return AUnit.Message_String;

   overriding
   procedure Register_Tests (T : in out Watch_Test_Case);

   overriding
   function Name (T : Watch_Test_Case) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("files native directory watching");
   end Name;

   Settle : constant Duration := 0.05;
   Rounds : constant Natural := 100;
   --  Notification is asynchronous on every platform, so a change is waited for
   --  rather than expected on the first poll -- up to five seconds, which is far
   --  beyond any plausible delivery and still bounded.

   function Wait_For_Change (State : in out Watch_State) return Boolean;

   function Wait_For_Change (State : in out Watch_State) return Boolean is
   begin
      for Unused_Round in 1 .. Rounds loop
         if Poll (State) then
            return True;
         end if;
         delay Settle;
      end loop;
      return False;
   end Wait_For_Change;

   procedure Drain (State : in out Watch_State);

   procedure Drain (State : in out Watch_State) is
      Ignored : Boolean;
   begin
      delay Settle;
      Ignored := Poll (State);
      pragma Unreferenced (Ignored);
   end Drain;

   procedure Touch (Directory : String; Name : String);

   procedure Touch (Directory : String; Name : String) is
      Output : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create
        (Output, Ada.Text_IO.Out_File,
         Ada.Directories.Compose (Directory, Name));
      Ada.Text_IO.Put_Line (Output, "x");
      Ada.Text_IO.Close (Output);
   end Touch;

   procedure Test_Inactive_By_Default
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      State : Watch_State;
   begin
      Assert (not Is_Active (State), "a fresh watch must be inactive");
      Assert (not Poll (State),
              "polling an inactive watch must report no change");
   end Test_Inactive_By_Default;

   procedure Test_Fails_Quietly (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      State : Watch_State;
   begin
      --  A watch that cannot be established must leave the caller to its polling
      --  timer, not raise: the listing still refreshes, just less promptly.
      Watch_Path (State, "/definitely/not/a/real/directory/xyzzy");
      Assert (not Is_Active (State),
              "an unwatchable path must not activate");
      Assert (not Poll (State),
              "a watch that failed must simply report no change");

      Watch_Path (State, "");
      Assert (not Is_Active (State), "an empty path must not activate");
   end Test_Fails_Quietly;

   procedure Test_Notices_Changes
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Directory : constant String :=
        Ada.Directories.Compose
          (Ada.Directories.Current_Directory, "watch_test_dir");
      State : Watch_State;
   begin
      if Ada.Directories.Exists (Directory) then
         Ada.Directories.Delete_Tree (Directory);
      end if;
      Ada.Directories.Create_Directory (Directory);

      Watch_Path (State, Directory);
      Assert (Is_Active (State),
              "watching a real directory must activate the native watch");

      Drain (State);
      Assert (not Poll (State),
              "a directory nobody touched must report no change");

      Touch (Directory, "created.txt");
      Assert (Wait_For_Change (State), "creating a file must be noticed");
      Assert (not Poll (State),
              "the change must be consumed, not reported twice");

      Ada.Directories.Delete_File
        (Ada.Directories.Compose (Directory, "created.txt"));
      Assert (Wait_For_Change (State), "deleting a file must be noticed");

      Assert (Event_Count (State) > 0, "events must be counted");

      Release (State);
      Assert (not Is_Active (State), "release must deactivate the watch");

      Ada.Directories.Delete_Tree (Directory);
   end Test_Notices_Changes;

   overriding
   procedure Register_Tests (T : in out Watch_Test_Case) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Inactive_By_Default'Access,
                        "a watch starts inactive");
      Register_Routine (T, Test_Fails_Quietly'Access,
                        "an unwatchable path fails quietly");
      Register_Routine (T, Test_Notices_Changes'Access,
                        "the native watch notices creations and deletions");
   end Register_Tests;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite :=
        new AUnit.Test_Suites.Test_Suite;
   begin
      pragma Warnings (Off, "use of an anonymous access type allocator");
      Result.Add_Test (new Watch_Test_Case);
      pragma Warnings (On, "use of an anonymous access type allocator");
      return Result;
   end Suite;

end Files_Suite.Watch;
