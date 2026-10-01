with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;

with Files.Job_Context;
with Files.Durable_Writes;
with Files.History_Journal;
with Files.Refresh_Jobs;
with Files.File_System;
with Files.Types;
with Files.Paste;
with Files.Process_Jobs;
with Hostkit.Fs;

package body Files.Operation_Jobs is
   use Ada.Strings.Unbounded;
   use type Files.Operations.Operation_Status;
   use type Files.Model.Undo_Action_Kind;
   use type Files.Settings.Settings_Model;

   type Request is record
      Kind     : Operation_Kind;
      Root     : Files.Types.UString;
      Recent   : Boolean;
      Query    : Files.Types.UString;
      Selected : Files.File_System.Item_Vectors.Vector;
      Settings : Files.Settings.Settings_Model;
      Undo, Redo : Files.Model.Undo_Entry_Vectors.Vector;
   end record;

   type Outcome is record
      Kind      : Operation_Kind;
      Recent    : Boolean := False;
      Result    : Files.Operations.Operation_Result;
      Items     : Files.File_System.Item_Vectors.Vector;
      Selection : Files.Types.UString;
      Visible_Error : Files.Types.UString;
      Signature : Files.File_System.Directory_Signature;
      History_Undo, History_Redo : Files.Model.Undo_Entry_Vectors.Vector;
   end record;

   function Start
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Kind : Operation_Kind) return Files.Operations.Operation_Result
   is
      Job  : Files.Process_Jobs.Session;
      File : Ada.Streams.Stream_IO.File_Type;
      Work : constant Request :=
        (Kind => Kind, Root => To_Unbounded_String (Files.Model.Current_Path (Model)),
         Recent => Files.Model.In_Recent_View (Model), Query => To_Unbounded_String (Files.Model.Filter_Text (Model)),
         Selected => Files.Model.Selected_Items (Model), Settings => Settings,
         Undo => Files.Model.Undo_History (Model), Redo => Files.Model.Redo_History (Model));
      Actions : Files.Paste.Resolved_Action_Vectors.Vector;
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) or else Files.Model.Paste_Conflict_Is_Active (Model) then
         return (Status => Files.Operations.Operation_Disabled, others => <>);
      end if;
      if Kind in Search_Names | Search_Contents and then Length (Work.Query) = 0 then
         Files.Model.Set_Error (Model, "error.filter.empty");
         return (Status => Files.Operations.Operation_Disabled,
                 Error_Key => To_Unbounded_String ("error.filter.empty"), others => <>);
      end if;
      if (Kind = Undo and then Work.Undo.Is_Empty) or else (Kind = Redo and then Work.Redo.Is_Empty) then
         Files.Model.Set_Error (Model, "error.undo.failed");
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.undo.failed"), others => <>);
      end if;
      if Kind not in Search_Names | Search_Contents | Undo | Redo | Empty_Trash
        and then (Work.Selected.Is_Empty or else Files.Model.Selection_Includes_Temporary (Model))
      then
         declare
            Key : constant String :=
              (case Kind is
                  when Duplicate => "error.duplicate.failed",
                  when Compress_Zip | Compress_Seven_Zip => "error.compress.failed",
                  when Extract => "error.extract.failed",
                  when Trash | Delete_Permanently | Restore => "error.selection.empty",
                  when others => "error.search.failed");
         begin
            Files.Model.Set_Error (Model, Key);
            return (Status => Files.Operations.Operation_Failed, Error_Key => To_Unbounded_String (Key), others => <>);
         end;
      end if;
      Files.Process_Jobs.Reserve (Job);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Files.Process_Jobs.Path (Job, "request"));
      Request'Output (Ada.Streams.Stream_IO.Stream (File), Work);
      Ada.Streams.Stream_IO.Close (File);
      Files.Process_Jobs.Launch (Job, "--files-operation");
      Actions.Append
        (Files.Paste.Resolved_Action'
           (Source_Path => Work.Root, Dest_Path => Work.Root, Skip => False, Replaced => False));
      Files.Model.Begin_Paste_Execution (Model, Actions, Files.File_System.Drop_Copy, Clear_Clipboard => False);
      Files.Model.Set_Error (Model, "");
      Files.Model.Set_Background_Operation
        (Model, Job,
         (case Kind is
             when Duplicate => "command.file.duplicate",
             when Compress_Zip => "command.file.compress_zip",
             when Compress_Seven_Zip => "command.file.compress_7z",
             when Extract => "command.file.extract",
             when Search_Names => "command.directory.search_recursive",
             when Search_Contents => "command.search.contents",
             when Trash => "command.file.delete",
             when Delete_Permanently => "command.file.delete_permanently",
             when Restore => "command.trash.restore",
             when Empty_Trash => "command.trash.empty",
             when Undo => "command.edit.undo",
             when Redo => "command.edit.redo"));
      return (Status => Files.Operations.Operation_Success, Path => Work.Root, others => <>);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Files.Model.Set_Error (Model, "error.drop.failed");
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.drop.failed"), others => <>);
   end Start;

   function Advance
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operations.Operation_Result
   is
      Job       : constant Files.Process_Jobs.Session := Files.Model.Background_Operation (Model);
      Finished  : Boolean;
      Cancelled : Boolean := False;
      File      : Ada.Streams.Stream_IO.File_Type;
      Done      : Outcome;
      Work      : Request;

      procedure Recover_Undo is
         Destinations, Sources, Identities, Tree_Revisions : Files.Types.String_Vectors.Vector;
         Untracked, Untracked_Identities, Untracked_Tree_Revisions : Files.Types.String_Vectors.Vector;
         Undo_Stack : constant Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Undo_History (Model);
         Redo_Stack : Files.Model.Undo_Entry_Vectors.Vector := Files.Model.Redo_History (Model);
         Tracked : Boolean;
      begin
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "request"));
         Work := Request'Input (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         Files.Job_Context.Read_Created
           (Files.Process_Jobs.Path (Job, ""), Destinations, Sources, Identities, Tree_Revisions);
         if Work.Kind = Redo and then not Redo_Stack.Is_Empty then
            declare
               Action : Files.Model.Undo_Entry := Redo_Stack.Last_Element;
            begin
               for Created_Index in Destinations.First_Index .. Destinations.Last_Index loop
                  declare
                     Dest : constant Files.Types.UString := Destinations (Created_Index);
                  begin
                     if Action.From.Contains (Dest) and then not Action.Forward_Completed.Contains (Dest) then
                        for Index in Action.From.First_Index .. Action.From.Last_Index loop
                           if Action.From (Index) = Dest then
                              while Action.Created_Identities.Last_Index < Index loop
                                 Action.Created_Identities.Append (Null_Unbounded_String);
                              end loop;
                              Action.Created_Identities.Replace_Element
                                (Index, Identities (Created_Index));
                              while Action.Created_Tree_Revisions.Last_Index < Index loop
                                 Action.Created_Tree_Revisions.Append (Null_Unbounded_String);
                              end loop;
                              Action.Created_Tree_Revisions.Replace_Element
                                (Index, Tree_Revisions (Created_Index));
                           end if;
                        end loop;
                        Action.Forward_Completed.Append (Dest);
                     end if;
                  end;
               end loop;
               Redo_Stack.Replace_Element (Redo_Stack.Last_Index, Action);
               Files.Model.Set_History (Model, Undo_Stack, Redo_Stack);
            end;
         elsif Work.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract then
            for Index in Destinations.First_Index .. Destinations.Last_Index loop
               Tracked := False;
               for Action of Undo_Stack loop
                  Tracked := Tracked or else Action.From.Contains (Destinations (Index));
               end loop;
               if not Tracked then
                  Untracked.Append (Destinations (Index));
                  Untracked_Identities.Append (Identities (Index));
                  Untracked_Tree_Revisions.Append (Tree_Revisions (Index));
               end if;
            end loop;
            if not Untracked.Is_Empty then
               Files.Model.Record_Undo
                 (Model, Files.Model.Undo_Delete_Created, Untracked,
                  Files.Types.String_Vectors.Empty_Vector, Redoable => False,
                  Original_Identities => Untracked_Identities,
                  Original_Tree_Revisions => Untracked_Tree_Revisions,
                  Retain_Verified_Main => Natural (Untracked.Length));
            end if;
         end if;
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
      end Recover_Undo;
   begin
      Files.Process_Jobs.Poll (Job, Finished, Cancelled);
      if not Finished then
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "result"));
      Done := Outcome'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      if Done.Kind in Search_Names | Search_Contents then
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Files.Process_Jobs.Path (Job, "request"));
         Work := Request'Input (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         if Work.Root /= Files.Model.Current_Path (Model) or else Work.Recent /= Files.Model.In_Recent_View (Model)
           or else Work.Query /= Files.Model.Filter_Text (Model) or else Work.Settings /= Settings
         then
            Files.Model.Clear_Paste_Execution (Model);
            return (Status => Files.Operations.Operation_Success, others => <>);
         end if;
      end if;
      Files.Model.Clear_Paste_Execution (Model);
      Files.Model.Set_History (Model, Done.History_Undo, Done.History_Redo);
      if Done.Result.Status /= Files.Operations.Operation_Success then
         Recover_Undo;
      end if;
      if Done.Kind in Trash | Delete_Permanently | Restore | Empty_Trash | Undo | Redo
        or else (Done.Kind in Duplicate | Compress_Zip | Compress_Seven_Zip | Extract
                 and then (Cancelled or else Done.Result.Status /= Files.Operations.Operation_Success))
      then
         --  Finalize error/history before the refresh captures this revision.
         Files.Model.Set_Error (Model, (if Cancelled then "" else To_String (Done.Visible_Error)));
         declare
            Reload : constant Files.Operations.Operation_Result := Files.Refresh_Jobs.Start (Model, Settings, True);
            pragma Unreferenced (Reload);
         begin
            null;
         end;
         return (if Cancelled then (Status => Files.Operations.Operation_Success, others => <>) else Done.Result);
      end if;
      if not Cancelled and then Done.Result.Status = Files.Operations.Operation_Success then
         if Done.Recent then
            Files.Model.Navigate_Recent (Model, Done.Items);
         else
            Files.Model.Replace_Items (Model, Done.Items);
         end if;
         Files.Model.Set_Directory_Signature (Model, Done.Signature);
         if Done.Kind in Search_Names | Search_Contents then
            Files.Model.Note_Search_Results
              (Model, (if Done.Kind = Search_Names then Files.Types.Search_Names else Files.Types.Search_Contents));
         else
            Files.Model.Clear_Search_Results (Model);
            if Length (Done.Selection) > 0 then
               declare
                  Selected : constant Boolean := Files.Model.Select_By_Name (Model, To_String (Done.Selection));
                  pragma Unreferenced (Selected);
               begin
                  null;
               end;
            end if;
         end if;
      end if;
      if Cancelled then
         Files.Model.Set_Error (Model, "");
         return (Status => Files.Operations.Operation_Success, others => <>);
      end if;
      Files.Model.Set_Error (Model, To_String (Done.Visible_Error));
      Files.Model.Ensure_Selected_Item_Extra (Model);
      return Done.Result;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         Files.Model.Clear_Paste_Execution (Model);
         declare
            Restored : constant Boolean :=
              Files.History_Journal.Restore (Files.Process_Jobs.Path (Job, ""), Model);
            pragma Unreferenced (Restored);
         begin
            null;
         end;
         Recover_Undo;
         --  Even an interrupted destructive operation may have changed the view.
         Files.Model.Set_Error (Model, (if Cancelled then "" else "error.drop.failed"));
         declare
            Reload : constant Files.Operations.Operation_Result := Files.Refresh_Jobs.Start (Model, Settings, True);
            pragma Unreferenced (Reload);
         begin
            null;
         end;
         if Cancelled then
            return (Status => Files.Operations.Operation_Success, others => <>);
         end if;
         return (Status => Files.Operations.Operation_Failed,
                 Error_Key => To_Unbounded_String ("error.drop.failed"), others => <>);
   end Advance;

   procedure Run_Helper (Directory : String) is
      File  : Ada.Streams.Stream_IO.File_Type;
      Work  : Request;
      Done  : Outcome;
      Model : Files.Model.Window_Model;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Hostkit.Fs.Join (Directory, "request"));
      Work := Request'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Done.Kind := Work.Kind;
      Files.Model.Initialize (Model, To_String (Work.Root), Work.Selected, Hostkit.Fs.Home_Directory);
      if Work.Recent then
         Files.Model.Navigate_Recent (Model, Work.Selected);
      end if;
      Files.Model.Set_History (Model, Work.Undo, Work.Redo);
      Files.History_Journal.Save (Model, Required => Work.Kind in Trash | Undo | Redo);
      if Work.Kind in Search_Names | Search_Contents then
         Files.Model.Set_Filter (Model, To_String (Work.Query));
      else
         Files.Model.Select_All_Visible (Model);
      end if;
      Done.Result :=
        (case Work.Kind is
            when Duplicate => Files.Operations.Duplicate_Selected (Model, Work.Settings),
            when Compress_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Zip_Archive),
            when Compress_Seven_Zip =>
              Files.Operations.Compress_Selected (Model, Work.Settings, Files.Operations.Seven_Zip_Archive),
            when Extract => Files.Operations.Extract_Selected (Model, Work.Settings),
            when Search_Names => Files.Operations.Run_Recursive_Search (Model, Work.Settings),
            when Search_Contents => Files.Operations.Run_Content_Search (Model, Work.Settings),
            when Trash => Files.Operations.Delete_Selected (Model, Work.Settings),
            when Delete_Permanently => Files.Operations.Delete_Selected_Permanently (Model, Work.Settings),
            when Restore => Files.Operations.Restore_Selected_From_Trash (Model, Work.Settings),
            when Empty_Trash => Files.Operations.Empty_Trash (Model, Work.Settings),
            when Undo => Files.Operations.Undo_Last (Model, Work.Settings),
            when Redo => Files.Operations.Redo_Last (Model, Work.Settings));
      Files.History_Journal.Save (Model);
      Done.Visible_Error := To_Unbounded_String
        (if Files.Model.Last_Error_Key (Model) = "" then To_String (Done.Result.Error_Key)
         else Files.Model.Last_Error_Key (Model));
      Done.Recent := Files.Model.In_Recent_View (Model);
      Done.Selection := To_Unbounded_String (Files.Model.Selected_Name (Model));
      for I in 1 .. Files.Model.Visible_Count (Model) loop
         Done.Items.Append (Files.Model.Visible_Item (Model, I));
      end loop;
      Done.Signature := Files.Model.Directory_Signature_Of (Model);
      Done.History_Undo := Files.Model.Undo_History (Model);
      Done.History_Redo := Files.Model.Redo_History (Model);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Hostkit.Fs.Join (Directory, "result.tmp"));
      Outcome'Output (Ada.Streams.Stream_IO.Stream (File), Done);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Publish
        (Hostkit.Fs.Join (Directory, "result.tmp"), Hostkit.Fs.Join (Directory, "result"))
      then
         raise Ada.Directories.Use_Error;
      end if;
   end Run_Helper;
end Files.Operation_Jobs;
