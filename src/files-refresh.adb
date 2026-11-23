with Files.Types;
with Files.Jobs.Process;
with Files.Model.Recent;
with Files.Model.Info_Pane;
with Files.Model.Filtering;
with Files.Model.Creation;
with Files.Model.Jobs;
with Files.Quick_Look.Preparation;
with Files.Jobs.Helper_Modes;
with Files.Diagnostics;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Files.IO.Record_Fields;
with Files.File_System;
with Files.File_System.Search;
with Files.File_Types;
with Files.Settings.Path_References;
with Files.Job_Payloads;
with Files.Jobs.Records;
with Files.IO.Lease_Streams;
with Files.IO.Errors;
with Hostkit.Fs;
with Files.Path_Checks;
with Files.Model.Command_Palette;
with Files.Model.Quick_Look;
with Files.Model.Rename;
with Files.Model.Selection;

package body Files.Refresh is
   use Ada.Strings.Unbounded;
   use type Files.Operation_Results.Operation_Status;

   Request_Header : constant String := "files-refresh-request-2";
   Result_Header : constant String := "files-refresh-result-2";

   type Request is record
      Root : Files.Types.UString;
      Context_Revision : Natural;
      Settings : Files.Settings.Settings_Model;
      Previous : Files.File_System_Types.Directory_Signature;
      Recent : Boolean;
      Force : Boolean;
      Selection : Files.Types.UString;
      Error_Key : Files.Types.UString;
      --  The full path to select, winning over Selection.
      Select_Path : Files.Types.UString;
      --  The scope whose results the window shows, to search again for
      --  Query rather than list the folder; Filter_Here lists it.
      Searched : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Query : Files.Types.UString;
   end record;

   type Outcome is record
      Success : Boolean := False;
      Reloaded : Boolean := False;
      Items : Files.Items.Item_Vectors.Vector;
      Signature : Files.File_System_Types.Directory_Signature;
      Error_Key : Files.Types.UString;
      --  A search's notice (as Files.File_System.Search.Search_Folder gives it), or "".
      Notice : Files.Types.UString;
   end record;

   function Request_Paths_Are_Consistent
     (Root, Previous_Path : String;
      Recent              : Boolean) return Boolean is
   begin
      if Recent then
         return Root = "" and then Previous_Path = "";
      end if;
      return Files.Path_Checks.Valid_Absolute_Path (Root)
        and then Files.Path_Checks.Valid_Absolute_Path (Previous_Path);
   end Request_Paths_Are_Consistent;

   function Is_Consistent (Done : Outcome) return Boolean is
     (Done.Success = (Length (Done.Error_Key) = 0)
      and then (not Done.Reloaded or else Done.Success));

   procedure Write_Request
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work : Request)
   is
   begin
      if not Request_Paths_Are_Consistent
        (To_String (Work.Root), To_String (Work.Previous.Path), Work.Recent)
      then
         raise Ada.Directories.Use_Error;
      end if;
      String'Output (Stream, Request_Header);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Root), Files.Jobs.Records.Max_Path_Length);
      Natural'Output (Stream, Work.Context_Revision);
      Files.Job_Payloads.Write_Settings (Stream, Work.Settings);
      Files.Jobs.Records.Write_Signature (Stream, Work.Previous);
      Boolean'Output (Stream, Work.Recent);
      Boolean'Output (Stream, Work.Force);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Selection), Files.Jobs.Records.Max_Path_Length);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Error_Key), Files.Jobs.Records.Max_Error_Length);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Select_Path), Files.Jobs.Records.Max_Path_Length);
      Files.UI_Types.Search_Scope'Output (Stream, Work.Searched);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Work.Query), Files.Jobs.Records.Max_Path_Length);
   end Write_Request;

   procedure Read_Request_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Work   : out Request) is
   begin
      Work.Root :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Context_Revision := Natural'Input (Stream);
      Work.Settings := Files.Job_Payloads.Read_Settings (Stream);
      Work.Previous := Files.Jobs.Records.Read_Signature (Stream);
      Work.Recent := Boolean'Input (Stream);
      Work.Force := Boolean'Input (Stream);
      Work.Selection :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Error_Key :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
      Work.Select_Path :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Work.Searched := Files.UI_Types.Search_Scope'Input (Stream);
      Work.Query :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
   end Read_Request_Body;

   function Request_Is_Consistent (Work : Request) return Boolean is
     (Request_Paths_Are_Consistent (To_String (Work.Root), To_String (Work.Previous.Path), Work.Recent));

   function Read_Request_Record is new Files.IO.Lease_Streams.Read_Record
     (Request, Read_Request_Body, Request_Is_Consistent);

   function Read_Request (Path : String) return Request is
     (Read_Request_Record (Path, Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   --  A request's leading fields: what a poll compares with the window.
   type Request_Identity is record
      Root             : Files.Types.UString;
      Context_Revision : Natural := 0;
   end record;

   procedure Read_Identity_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Ident  : out Request_Identity) is
   begin
      Ident.Root :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Path_Length));
      Ident.Context_Revision := Natural'Input (Stream);
   end Read_Identity_Body;

   function Identity_Is_Consistent (Ident : Request_Identity) return Boolean is
     (Length (Ident.Root) = 0 or else Files.Path_Checks.Valid_Absolute_Path (To_String (Ident.Root)));

   function Read_Identity_Record is new Files.IO.Lease_Streams.Read_Record
     (Request_Identity, Read_Identity_Body, Identity_Is_Consistent, Whole => False);

   function Read_Request_Identity (Path : String) return Request_Identity is
     (Read_Identity_Record (Path, Request_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   procedure Write_Outcome
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done : Outcome)
   is
   begin
      if not Is_Consistent (Done) then
         raise Ada.IO_Exceptions.Use_Error;
      end if;
      String'Output (Stream, Result_Header);
      Boolean'Output (Stream, Done.Success);
      Boolean'Output (Stream, Done.Reloaded);
      Files.Job_Payloads.Write_Items (Stream, Done.Items);
      Files.Jobs.Records.Write_Signature (Stream, Done.Signature);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Done.Error_Key), Files.Jobs.Records.Max_Error_Length);
      Files.IO.Record_Fields.Output_String
        (Stream, To_String (Done.Notice), Files.Jobs.Records.Max_Error_Length);
   end Write_Outcome;

   procedure Read_Outcome_Body
     (Stream : not null access Ada.Streams.Root_Stream_Type'Class;
      Done   : out Outcome) is
   begin
      Done.Success := Boolean'Input (Stream);
      Done.Reloaded := Boolean'Input (Stream);
      Done.Items := Files.Job_Payloads.Read_Items (Stream);
      Done.Signature := Files.Jobs.Records.Read_Signature (Stream);
      Done.Error_Key :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
      Done.Notice :=
        To_Unbounded_String (Files.IO.Record_Fields.Input_String (Stream, Files.Jobs.Records.Max_Error_Length));
   end Read_Outcome_Body;

   function Read_Outcome_Record is new Files.IO.Lease_Streams.Read_Record
     (Outcome, Read_Outcome_Body, Is_Consistent);

   function Read_Outcome (Path : String) return Outcome is
     (Read_Outcome_Record (Path, Result_Header, Long_Long_Integer (Files.Jobs.Records.Max_Transport_Bytes)));

   procedure Cancel (Model : in out Files.Model.Window_Model) is
      Empty : Files.Jobs.Process.Session;
   begin
      Files.Model.Jobs.Set_Background_Refresh (Model, Empty);
   end Cancel;

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Force : Boolean := False;
      Select_Name : String := "";
      Select_Path : String := "";
      Search_Again : Boolean := False) return Files.Operation_Results.Operation_Result is separate;

   procedure Resume_Owed
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if not Files.Model.Refresh_Is_Owed (Model)
        or else Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model))
        or else Files.Model.Jobs.Foreground_Job_Is_Active (Model)
      then
         return;
      end if;

      declare
         Retry : constant Files.Operation_Results.Operation_Result :=
           Start (Model, Settings,
                  Force       => Files.Model.Owed_Refresh_Force (Model),
                  Select_Name => Files.Model.Owed_Refresh_Selection (Model),
                  Select_Path => Files.Model.Owed_Refresh_Path (Model),
                  --  Search results shown now are searched again: a
                  --  listing put in their place would pass for them.
                  Search_Again => True);
      begin
         --  A launch settles the debt inside Start. A launch failure has
         --  already reported its error; retrying it every poll would not help.
         if Retry.Status = Files.Operation_Results.Operation_Failed then
            Files.Model.Clear_Owed_Refresh (Model);
         end if;
      end;
   end Resume_Owed;

   --  A read of the directory still on screen went stale because something
   --  listing-visible changed (an error, an edit, Settings). Its answer must
   --  not be applied, but the reload it stood for is still owed; Resume_Owed
   --  reissues it against the current state on a later poll.
   procedure Owe_Reload (Model : in out Files.Model.Window_Model; Job : Files.Jobs.Process.Session) is
   begin
      declare
         Stale : constant Request := Read_Request (Files.Jobs.Process.Path (Job, Files.Jobs.Process.Request_File));
      begin
         Files.Model.Note_Owed_Refresh
           (Model, Stale.Force, To_String (Stale.Selection), Select_Path => To_String (Stale.Select_Path));
      end;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.Refresh");
         Files.Model.Note_Owed_Refresh (Model, False, "");
   end Owe_Reload;

   --  How every view shown anew ends: Error_Line on the error line (set
   --  only when it differs) and the selected item's details read.
   procedure Settle_Shown
     (Model       : in out Files.Model.Window_Model;
      Error_Line  : String;
      Show_Hidden : Boolean) is
   begin
      if Files.Model.Last_Error_Key (Model) /= Error_Line then
         Files.Model.Set_Error (Model, Error_Line);
      end if;
      Ensure_Selected_Item_Extra (Model, Show_Hidden);
   end Settle_Shown;

   procedure Reinstall_Listing
     (Model          : in out Files.Model.Window_Model;
      Items          : Files.Items.Item_Vectors.Vector;
      Signature      : Files.File_System_Types.Directory_Signature;
      Recent         : Boolean := False;
      Searched       : Files.UI_Types.Search_Scope := Files.UI_Types.Filter_Here;
      Query          : String := "";
      New_Results    : Boolean := False;
      Select_Path    : String := "";
      Select_Name    : String := "";
      Keep_Selection : Boolean := True;
      Fresh_Details  : Boolean := False;
      Owe_Thumbnails : Boolean := False;
      Show_Hidden    : Boolean;
      Error_Line     : String := "") is separate;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Boolean is separate;

   procedure Run_Helper (Directory : String) is separate;

   procedure Ensure_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Show_Hidden : Boolean) is
   begin
      if not Files.Model.Jobs.Background_Transfers (Model)
        and then Files.Model.Info_Pane.Selected_Item_Needs_Extra (Model)
      then
         declare
            Item : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
         begin
            Files.Model.Info_Pane.Set_Selected_Item_Extra
              (Model,
               Files.File_System.Extra_Info_Of
                 (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype), Show_Hidden));
         end;
      end if;
   end Ensure_Selected_Item_Extra;

   function Load_Recent_Items (Settings : Files.Settings.Settings_Model) return Files.Items.Item_Vectors.Vector is
      Classes : constant Files.File_Types.Classification := Files.Settings.Classification_Of (Settings);
      Items   : Files.Items.Item_Vectors.Vector;
   begin
      for Path of Files.Settings.Path_References.Recent_Paths (Settings) loop
         declare
            Loaded : constant Files.File_System.Item_Load_Result :=
              Files.File_System.Load_Item (To_String (Path), Classes);
         begin
            if Loaded.Success then
               Items.Append (Loaded.Item);
            end if;
         end;
      end loop;
      return Items;
   end Load_Recent_Items;

end Files.Refresh;
