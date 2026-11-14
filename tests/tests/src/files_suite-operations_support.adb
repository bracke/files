with Files.Process_Jobs;
with Files.Refresh_Jobs;
with Files.Extra_Info_Reader;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with AUnit.Assertions;
with Project_Tools.Files;
with GNAT.OS_Lib;
with Hostkit.Host;
with Hostkit.Process;
with Files.Application.Windows;
with Files.Events;
with Files.File_System;
with Files.Interaction;
with Files.Localization;
with Hostkit.Fs;
with Hostkit.Metadata;
with Guikit.Input;
with Files_Suite.Support;
with Files.Model.Pasting;

package body Files_Suite.Operations_Support is

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   use type Files.Events.Input_Action_Kind;
   use type Files.Operations.Operation_Status;
   use Files_Suite.Support;

   function Complete_Operation
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Started : Files.Operations.Operation_Result) return Files.Operations.Operation_Result is
     (if Files.Model.Pasting.Execution_Is_Active (Model) then Finish_Paste (Model, Settings) else Started);

   procedure Await_Item_Details (Model : in out Files.Model.Window_Model) is
   begin
      for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
         Files.Operations.Poll_Selected_Item_Extra (Model, Files.Extra_Info_Reader.Requester (77));
         exit when not Files.Model.Selected_Item_Needs_Extra (Model);
      end loop;
      Assert (not Files.Model.Selected_Item_Needs_Extra (Model), "the window's poll brings the details in");
   end Await_Item_Details;

   procedure Unlock_Directory (Directory : String) is
      Unlocked : constant Files.File_System.Mutation_Result :=
        Files.File_System.Set_Permissions (Directory, 8#755#);
      pragma Unreferenced (Unlocked);
   begin
      null;
   end Unlock_Directory;

   function Lock_Directory (Directory : String) return Boolean is
      use type GNAT.OS_Lib.File_Descriptor;
      Probe : constant String := Join (Directory, ".write-probe");
      Descriptor : GNAT.OS_Lib.File_Descriptor;
   begin
      --  Every host is asked: the probe below says where a mode does not
      --  stop a write (Windows), and the refusal's mapping is host code
      --  worth proving on macOS too.
      if (Hostkit.Metadata.Mode_Bits_Are_Native and then Hostkit.Host.Is_Elevated)
        or else not Files.File_System.Set_Permissions (Directory, 8#555#).Success
      then
         return False;
      end if;
      Descriptor := GNAT.OS_Lib.Create_New_File (Probe, GNAT.OS_Lib.Binary);
      if Descriptor = GNAT.OS_Lib.Invalid_FD then
         return True;
      end if;
      GNAT.OS_Lib.Close (Descriptor);
      Unlock_Directory (Directory);
      Ada.Directories.Delete_File (Probe);
      return False;
   end Lock_Directory;

   procedure With_Trash_Environment (Check : not null access procedure) is separate;

   function Detail_Value (Key : String; Name : String; Value : String) return String is separate;

   function Detail_Localized_Value (Key : String; Name : String; Value_Key : String) return String is separate;

   function Detail_Lines_Encoding (Key : String; Lines : String; Encoding_Key : String) return String is separate;

   procedure Write_Info_Metadata_Fixtures is separate;

   procedure With_Desktop_Application_Fixture (Check : not null access procedure) is separate;

   function Find_Application
     (Apps : Files.Desktop_Applications.Application_Vectors.Vector;
      Name : String)
      return Files.Desktop_Applications.Application is separate;

   procedure Create_Abandoned_Transport (Report : String; Path : out Files.Types.UString) is separate;

   function Nul_Name return String is ("bad" & Character'Val (0) & "name.txt");
   function Tab_Name return String is ("bad" & Character'Val (9) & "name.txt");
   function C1_Name return String is ("bad" & Character'Val (133) & "name.txt");
   function Encoded_C1_Name return String is ("bad" & Byte (16#C2#) & Byte (16#85#) & "name.txt");
   function Truncated_UTF8_Name return String is ("bad" & Byte (16#E2#) & Byte (16#82#) & "name.txt");
   function Overlong_UTF8_Name return String is ("bad" & Byte (16#C0#) & Byte (16#AF#) & "name.txt");
   function NBSP_Name return String is
     (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#)));
   function Ideographic_Space_Name return String is
     (Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#3000#)));
   function Trailing_NBSP_Name return String is ("trailing-nbsp" & NBSP_Name);
   function Trailing_Ideographic_Name return String is ("trailing-wide" & Ideographic_Space_Name);

   procedure Await_View
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Applied  : out Boolean) is
   begin
      Applied := False;
      for Attempt in Files_Suite.Support.Polling loop
         Applied := Files.Refresh_Jobs.Advance (Model, Settings) or else Applied;
         exit when not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
      end loop;
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "the operation's reload completes");
   end Await_View;

   procedure Await_View (Model : in out Files.Model.Window_Model; Settings : Files.Settings.Settings_Model) is
      Applied : Boolean;
   begin
      Await_View (Model, Settings, Applied);
      pragma Unreferenced (Applied);
   end Await_View;

   procedure Await_Refresh_Ready (Model : Files.Model.Window_Model; What : String) is
      Job : constant Files.Process_Jobs.Session := Files.Model.Background_Refresh (Model);
      Finished, Cancelled : Boolean;
   begin
      for Attempt in Polling loop
         Files.Process_Jobs.Poll (Job, Finished, Cancelled);
         exit when Finished;
      end loop;
      Assert (Finished and then not Cancelled, What);
   end Await_Refresh_Ready;

   procedure Await_Refresh_Applied
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Expected : Boolean;
      What     : String)
   is
      Applied : Boolean := False;
   begin
      Await_View (Model, Settings, Applied);
      Assert (not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)), What & ": the read ends");
      Files_Suite.Support.Assert_Equal (Applied, Expected, What);
   end Await_Refresh_Applied;

   function Metadata_Mode_Of (Path : String) return Natural is
      Available : Boolean;
      Mode : constant Natural := Files.File_System.Permission_Bits_Of (Path, Available);
   begin
      Assert (Available, "metadata mode is available");
      return Mode;
   end Metadata_Mode_Of;

   function Is_Owner_Only (Path : String) return Boolean is
      Mode  : constant Natural := Metadata_Mode_Of (Path);
      Owner : constant Natural := (Mode / 8#100#) mod 8;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         return not Hostkit.Fs.Directory_Accessible_By_Others (Path);
      end if;
      return Owner in 6 | 7 and then Mode mod 8#100# = 0;
   end Is_Owner_Only;

   function Mode_Of (Path : String) return Natural is
      Available : Boolean := False;
      Bits      : constant Natural := Files.File_System.Permission_Bits_Of (Path, Available);
   begin
      Assert (Available, "permission bits are readable for " & Path);
      return Bits mod 8#1000#;
   end Mode_Of;

   procedure Confirm_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model)
   is
      IR : Files.Interaction.Interaction_Result;
   begin
      Files.Interaction.Apply_Input_Action
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Action            => (Kind => Files.Events.Tree_Pick_Confirm_Input_Action),
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => IR);
   end Confirm_Pick;

   procedure Finish_Background_Operation
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Step     : in out Files.Operations.Operation_Result) is
   begin
      Assert (Files.Model.Pasting.Execution_Is_Active (Model),
              "a long operation returns with its progress overlay open");
      Step := Files_Suite.Support.Finish_Paste (Model, Settings);
      Assert (not Files.Model.Pasting.Execution_Is_Active (Model),
              "the UI collects the helper result without blocking");
      Files_Suite.Support.Assert_Equal
        (Step.Status,
         Files.Operations.Operation_Success,
         "the background operation completes successfully");
   end Finish_Background_Operation;

end Files_Suite.Operations_Support;
