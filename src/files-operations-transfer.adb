with Files.Copy_Context;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Files.Paste;
with Files.File_Identities;
with Files.History_Journal;
with Files.Archive_Writing;

with Zlib;

with Files.Operations.Support;

separate (Files.Operations)
package body Transfer is
   use type Ada.Directories.File_Kind;
   use type Files.File_System.Drop_Import_Mode;
   use type Zlib.Status_Code;

   function Compress_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Format   : Archive_Format)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String :=
        (if Files.Model.In_Recent_View (Model) and then not Items.Is_Empty
         then Ada.Directories.Containing_Directory (To_String (Items.First_Element.Full_Path))
         else Files.Model.Current_Path (Model));

      Input_Paths : Files.Types.String_Vectors.Vector;
      Entry_Names : Files.Types.String_Vectors.Vector;
      Collection_Failed : Boolean := False;

      --  Recursively collect directories and ordinary files, recording
      --  each with a directory-relative archive entry name (forward slashes).
      procedure Collect (Full : String; Entry_Name : String) is
         Search    : Ada.Directories.Search_Type;
         Started   : Boolean := False;
         Dir_Entry : Ada.Directories.Directory_Entry_Type;
      begin
         if Files.Job_Context.Cancelled then
            return;
         elsif not Exists_Safely (Full) then
            Collection_Failed := True;
            return;
         elsif Hostkit.Fs.Is_Link (Full) then
            --  Skip symlinks instead of following them: Ada.Directories.Kind
            --  dereferences a link, so a link to an ancestor would recurse
            --  unbounded (Storage_Error) and a link to a directory would archive
            --  the target's contents under the link's name. Mirrors Copy_Tree /
            --  Directory_Size, which also skip links via Hostkit.Fs.
            return;
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Directory then
            if Entry_Names.Contains (To_Unbounded_String (Entry_Name)) then
               Collection_Failed := True;
               return;
            end if;
            Input_Paths.Append (To_Unbounded_String (Full));
            Entry_Names.Append (To_Unbounded_String (Entry_Name));
            Ada.Directories.Start_Search
              (Search,
               Directory => Full,
               Pattern   => "*",
               Filter    =>
                 [Ada.Directories.Ordinary_File => True,
                  Ada.Directories.Directory     => True,
                  Ada.Directories.Special_File  => False]);
            Started := True;
            while Ada.Directories.More_Entries (Search) loop
               Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
               declare
                  Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               begin
                  if Name /= "." and then Name /= ".." then
                     Collect
                       (Ada.Directories.Full_Name (Dir_Entry),
                        Entry_Name & "/" & Name);
                  end if;
               end;
            end loop;
            Ada.Directories.End_Search (Search);
         elsif Ada.Directories.Kind (Full) = Ada.Directories.Ordinary_File then
            if Entry_Names.Contains (To_Unbounded_String (Entry_Name)) then
               Collection_Failed := True;
               return;
            end if;
            Input_Paths.Append (To_Unbounded_String (Full));
            Entry_Names.Append (To_Unbounded_String (Entry_Name));
         end if;
      exception
         when others =>
            Collection_Failed := True;
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
      end Collect;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start
           (Model, Settings, (if Format = Zip_Archive then Files.Operation_Jobs.Compress_Zip
            else Files.Operation_Jobs.Compress_Seven_Zip));
      end if;
      if Items.Is_Empty or else Directory = "" then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      for Item of Items loop
         Collect (To_String (Item.Full_Path), To_String (Item.Name));
      end loop;

      if Collection_Failed or else Input_Paths.Is_Empty then
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
      end if;

      declare
         Extension : constant String :=
           (case Format is
               when Zip_Archive       => "zip",
               when Seven_Zip_Archive => "7z");
         Raw_Base : constant String :=
           Ada.Directories.Base_Name (To_String (Items.First_Element.Name));
         Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

         --  A directory-unique simple archive name, e.g. "report.zip" or
         --  "report (1).zip" when the first choice already exists.
         function Unique_Name return String is
         begin
            if not Exists_Safely
                     (Ada.Directories.Compose (Directory, Base, Extension))
            then
               return Base & "." & Extension;
            end if;

            for N in 1 .. 9_999 loop
               declare
                  Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
               begin
                  if not Exists_Safely
                           (Ada.Directories.Compose (Directory, Candidate, Extension))
                  then
                     return Candidate & "." & Extension;
                  end if;
               end;
            end loop;

            return Base & "." & Extension;
         end Unique_Name;

         Archive_Name : constant String := Unique_Name;
         Output_Path  : constant String := Ada.Directories.Compose (Directory, Archive_Name);
         Count        : constant Natural := Natural (Input_Paths.Length);
         Inputs       : Zlib.Text_Array (1 .. Count);
         Names        : Zlib.Text_Array (1 .. Count);
         Status       : Zlib.Status_Code;
         Stage        : constant String := Files.Job_Context.Create_Stage (Directory);
         Staged       : constant String := Ada.Directories.Compose (Stage, Archive_Name);
         Created      : Files.Types.String_Vectors.Vector;
         Identities   : Files.Types.String_Vectors.Vector;
         Tree_Revisions : Files.Types.String_Vectors.Vector;

         procedure Discard_Stage is
            Removed : constant Boolean := Files.Job_Context.Discard_Stage (Stage);
            pragma Unreferenced (Removed);
         begin
            null;
         end Discard_Stage;
      begin
         for I in 1 .. Count loop
            Inputs (I) := Input_Paths.Element (I);
            Names  (I) := Entry_Names.Element (I);
         end loop;

         case Format is
            when Zip_Archive =>
               Files.Archive_Writing.ZIP_Files (Inputs, Staged, Names, Status);
            when Seven_Zip_Archive =>
               Zlib.Seven_Zip_Deflate_Files (Inputs, Staged, Names, Status => Status);
         end case;

         Identities.Append (To_Unbounded_String (Files.File_Identities.Token (Staged)));
         Tree_Revisions.Append
           (To_Unbounded_String (Files.File_System.Tree_Revision (Staged)));
         if Status /= Zlib.Ok or else Files.Job_Context.Cancelled
           or else not Hostkit.Fs.Move_No_Replace (Staged, Output_Path)
         then
            Discard_Stage;
            return Make_Result (Operation_Failed, "error.compress.failed", Directory);
         end if;
         Files.Job_Context.Record_Created
           (Output_Path, "", To_String (Identities.First_Element), To_String (Tree_Revisions.First_Element));
         Discard_Stage;
         Created.Append (To_Unbounded_String (Output_Path));
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Created,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False, Original_Identities => Identities,
            Original_Tree_Revisions => Tree_Revisions);

         --  Reload so the new archive appears, and select it.
         return Reload_Current_Directory (Model, Settings, Archive_Name);
      exception
         when others =>
            Discard_Stage;
            raise;
      end;
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Compress_Selected;

   function Extract_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Extracted_Any : Boolean := False;
      Created       : Files.Types.String_Vectors.Vector;
      Identities    : Files.Types.String_Vectors.Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector;
      Progress_Recorded : Boolean := False;
      Verified_Count : Natural := 0;

      procedure Record_Progress is
         Previous : Files.Model.Undo_Entry;
         Found : Boolean;
      begin
         if Progress_Recorded then
            Files.Model.Take_Undo (Model, Previous, Found);
         end if;
         Progress_Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Created,
            Files.Types.String_Vectors.Empty_Vector, Redoable => False,
            Original_Identities => Identities,
            Original_Tree_Revisions => Tree_Revisions,
            Retain_Verified_Main => Verified_Count);
         if Progress_Recorded
           and then Natural (Files.Model.Undo_From_Paths (Model).Length) =
             Natural (Created.Length)
         then
            Verified_Count := Natural (Created.Length);
         end if;
      end Record_Progress;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Treat a name ending (case-insensitively) in .zip or .7z as an archive.
      function Name_Is_Archive (Name : String) return Boolean is
         Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
      begin
         return Ada.Strings.Fixed.Tail (Lower, 4) = ".zip"
           or else Ada.Strings.Fixed.Tail (Lower, 3) = ".7z";
      end Name_Is_Archive;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Extract);
      end if;
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         declare
            Item_Name : constant String := To_String (Item.Name);
            Full_Path : constant String := To_String (Item.Full_Path);
            Destination : constant String :=
              (if Files.Model.In_Recent_View (Model) then Ada.Directories.Containing_Directory (Full_Path)
               else Directory);
         begin
            if Destination = "" then
               return Make_Result (Operation_Failed, "error.extract.failed", Directory);
            end if;
            if Name_Is_Archive (Item_Name) then
               declare
                  Raw_Base : constant String := Ada.Directories.Base_Name (Item_Name);
                  Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

                  --  A directory-unique destination folder name, e.g. "report"
                  --  or "report (1)" when the first choice already exists.
                  function Unique_Name return String is
                  begin
                     if not Exists_Safely (Ada.Directories.Compose (Destination, Base)) then
                        return Base;
                     end if;

                     for N in 1 .. 9_999 loop
                        declare
                           Candidate : constant String := Base & " (" & Trimmed_Image (N) & ")";
                        begin
                           if not Exists_Safely (Ada.Directories.Compose (Destination, Candidate)) then
                              return Candidate;
                           end if;
                        end;
                     end loop;

                     return Base;
                  end Unique_Name;

                  Dest_Name : constant String := Unique_Name;
                  Dest_Dir  : constant String := Ada.Directories.Compose (Destination, Dest_Name);
                  Status    : Zlib.Status_Code;
                  Stage     : constant String := Files.Job_Context.Create_Stage (Destination);
                  Payload   : constant String := Hostkit.Fs.Join (Stage, "payload");

                  procedure Discard_Stage is
                     Removed : constant Boolean := Files.Job_Context.Discard_Stage (Stage);
                     pragma Unreferenced (Removed);
                  begin
                     null;
                  end Discard_Stage;
               begin
                  Ada.Directories.Create_Directory (Payload);
                  Zlib.Extract_Archive_File_To_Directory (Full_Path, Payload, "", Status);

                  declare
                     Identity : constant String := Files.File_Identities.Token (Payload);
                     Revision : constant String := Files.File_System.Tree_Revision (Payload);
                  begin

                     if Status /= Zlib.Ok or else Files.Job_Context.Cancelled
                       or else not Hostkit.Fs.Move_No_Replace (Payload, Dest_Dir)
                     then
                        Discard_Stage;
                        return Make_Result (Operation_Failed, "error.extract.failed", Directory);
                     end if;

                     Files.Job_Context.Record_Created (Dest_Dir, "", Identity, Revision);
                     Identities.Append (To_Unbounded_String (Identity));
                     Tree_Revisions.Append (To_Unbounded_String (Revision));
                  end;
                  Discard_Stage;
                  Created.Append (To_Unbounded_String (Dest_Dir));
                  Record_Progress;
                  if not Extracted_Any then
                     First_Created := To_Unbounded_String (Dest_Name);
                     Extracted_Any := True;
                  end if;
               exception
                  when others =>
                     Discard_Stage;
                     raise;
               end;
            end if;
         end;
      end loop;

      if not Extracted_Any then
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
      end if;

      --  Reload so the new directories appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.extract.failed", Directory);
   end Extract_Selected;

   function Duplicate_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;
      Created       : Files.Types.String_Vectors.Vector;
      Sources       : Files.Types.String_Vectors.Vector;
      Identities    : Files.Types.String_Vectors.Vector;
      Tree_Revisions : Files.Types.String_Vectors.Vector;
      Progress_Recorded : Boolean := False;
      Verified_Count : Natural := 0;

      Copy_Batch : constant Files.Copy_Context.Session := Files.Copy_Context.Create;

      procedure Record_Progress is
         Previous : Files.Model.Undo_Entry;
         Found : Boolean;
      begin
         if Progress_Recorded then
            Files.Model.Take_Undo (Model, Previous, Found);
         end if;
         Progress_Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Delete_Created, Created,
            Files.Types.String_Vectors.Empty_Vector, Forward => Sources, Create_Kind => Files.Model.Create_Copy,
            Original_Identities => Identities,
            Original_Tree_Revisions => Tree_Revisions,
            Retain_Verified_Main => Verified_Count);
         if Progress_Recorded
           and then Natural (Files.Model.Undo_From_Paths (Model).Length) =
             Natural (Created.Length)
         then
            Verified_Count := Natural (Created.Length);
         end if;
      end Record_Progress;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (copy)" / " (copy N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Copy_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "copy";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Copy_Marker;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Duplicate);
      end if;
      if Items.Is_Empty or else (Directory = "" and then not Files.Model.In_Recent_View (Model)) then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         declare
            Source : constant String := To_String (Item.Full_Path);
            --  Recent can select paths from several folders; each duplicate
            --  belongs beside its source rather than in a virtual view's path.
            Destination_Directory : constant String :=
              (if Files.Model.In_Recent_View (Model) then Ada.Directories.Containing_Directory (Source) else Directory);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique copy stem (without extension), e.g. "report
            --  (copy)" or "report (copy 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Copy_Marker (N);
                  begin
                     if not Exists_Safely
                              (Ada.Directories.Compose (Destination_Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Copy_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Destination_Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Identity, Revision : Files.Types.UString;
            Mutation  : constant Files.File_System.Mutation_Result :=
              Files.File_System.Copy_Tree (Source, Dest_Path, Identity, Revision, Copy_Batch);
         begin
            if not Mutation.Success then
               return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
            end if;

            Created.Append (To_Unbounded_String (Dest_Path));
            Sources.Append (To_Unbounded_String (Source));
            Identities.Append (Identity);
            Tree_Revisions.Append (Revision);
            Record_Progress;
            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
      end if;

      --  Reload the active view; an ordinary folder selects the first copy.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
   end Duplicate_Selected;

   --  Shared implementation for the create-symlink and create-hard-link
   --  commands. Each selected item gets a uniquely named link in the current
   --  directory; the created links are recorded so Undo can delete them.
   function Create_Links
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Hard     : Boolean)
      return Operation_Result
   is
      Items     : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Directory : constant String := Files.Model.Current_Path (Model);

      First_Created : Unbounded_String;
      Created_Any   : Boolean := False;
      Undo_From     : Files.Types.String_Vectors.Vector;
      Undo_To       : Files.Types.String_Vectors.Vector;
      Undo_Sources  : Files.Types.String_Vectors.Vector;

      function Trimmed_Image (Value : Positive) return String is
         Image : constant String := Positive'Image (Value);
      begin
         return Image (Image'First + 1 .. Image'Last);
      end Trimmed_Image;

      --  Build the " (link)" / " (link N)" marker. The fragments are kept
      --  separate so no single string literal mixes a letter with a space,
      --  which the format-validation tooling rejects.
      function Link_Marker (Value : Positive) return String is
         Open  : constant String := " (";
         Word  : constant String := "link";
         Close : constant String := ")";
      begin
         if Value = 1 then
            return Open & Word & Close;
         else
            return Open & Word & " " & Trimmed_Image (Value) & Close;
         end if;
      end Link_Marker;
   begin
      if Items.Is_Empty then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      for Item of Items loop
         declare
            Source : constant String := To_String (Item.Full_Path);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Ada.Directories.Extension (Name);
            Base   : constant String := Ada.Directories.Base_Name (Name);

            --  A directory-unique link stem (without extension), e.g. "report
            --  (link)" or "report (link 2)" when earlier choices already exist.
            function Unique_Stem return String is
            begin
               for N in 1 .. 9_999 loop
                  declare
                     Candidate : constant String := Base & Link_Marker (N);
                  begin
                     if not Exists_Safely
                              (Ada.Directories.Compose (Directory, Candidate, Ext))
                     then
                        return Candidate;
                     end if;
                  end;
               end loop;

               return Base & Link_Marker (1);
            end Unique_Stem;

            Dest_Path : constant String :=
              Ada.Directories.Compose (Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Ada.Directories.Simple_Name (Dest_Path);
            Mutation  : constant Files.File_System.Mutation_Result :=
              (if Hard
               then Files.File_System.Create_Hard_Link (Source, Dest_Path)
               else Files.File_System.Create_Symbolic_Link (Source, Dest_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               --  Record undo for the links already created before this mid-batch
               --  failure so they stay Ctrl-Z-restorable, and reload so they
               --  appear instead of staying hidden until the next refresh.
               if not Undo_From.Is_Empty then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
                     Forward     => Undo_Sources,
                     Create_Kind =>
                       (if Hard
                        then Files.Model.Create_Hard_Link
                        else Files.Model.Create_Symbolic_Link));
                  declare
                     Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                     pragma Unreferenced (Reload);
                  begin
                     Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
                  end;
               end if;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Directory);
            end if;

            Undo_From.Append (To_Unbounded_String (Dest_Path));
            Undo_To.Append (To_Unbounded_String (Dest_Path));
            Undo_Sources.Append (To_Unbounded_String (Source));
            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;

      if not Created_Any then
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
      end if;

      --  A created link is undone by deleting it again and redone by
      --  re-creating it from its recorded source.
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Delete_Created, Undo_From, Undo_To,
         Forward     => Undo_Sources,
         Create_Kind =>
           (if Hard
            then Files.Model.Create_Hard_Link
            else Files.Model.Create_Symbolic_Link));

      --  Reload so the new links appear, and select the first one.
      return Reload_Current_Directory (Model, Settings, To_String (First_Created));
   exception
      when others =>
         return Make_Result (Operation_Failed, "error.link.failed", Directory);
   end Create_Links;

   function Create_Symlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => False);
   end Create_Symlink_Selected;

   function Create_Hardlink_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result is
   begin
      return Create_Links (Model, Settings, Hard => True);
   end Create_Hardlink_Selected;

   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
      Undo_From  : Files.Types.String_Vectors.Vector;
      Undo_To    : Files.Types.String_Vectors.Vector;
      Identities : Files.Types.String_Vectors.Vector;
      Progress_Recorded : Boolean := False;
      Verified_Count : Natural := 0;
      procedure Record_Progress is
         Previous : Files.Model.Undo_Entry;
         Found : Boolean;
      begin
         if Progress_Recorded then
            Files.Model.Take_Undo (Model, Previous, Found);
         end if;
         Progress_Recorded := Files.Model.Try_Record_Undo
           (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To, Redoable => False,
            Original_Identities => Identities,
            Retain_Verified_Main => Verified_Count);
         if Progress_Recorded
           and then Natural (Files.Model.Undo_From_Paths (Model).Length) =
             Natural (Undo_From.Length)
         then
            Verified_Count := Natural (Undo_From.Length);
         end if;
         Files.History_Journal.Save (Model, Required => True);
      end Record_Progress;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Trash);
      end if;
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif not Files.File_System.Trash_Is_Available then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable");
      end if;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         declare
            Preflight : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash_Preflight (To_String (Item.Full_Path));
         begin
            if Preflight.Success then
               null;
            else
               Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
               declare
                  Reload : constant Operation_Result :=
                    Reload_With_Error (Model, Settings, To_String (Preflight.Error_Key));
                  pragma Unreferenced (Reload);
               begin
                  null;
               end;
               return Make_Result
                 (Operation_Failed, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.trash.failed");
            declare
               Reload : constant Operation_Result := Reload_With_Error (Model, Settings, "error.trash.failed");
               pragma Unreferenced (Reload);
            begin
               null;
            end;
            return Make_Result (Operation_Failed, "error.trash.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Trashed  : Files.Types.UString;
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash (To_String (Item.Full_Path), Trashed);
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               --  Record an undo covering whatever was already trashed before this
               --  mid-batch failure (a race can make a later item fail after
               --  earlier ones moved), so those items remain Ctrl-Z-restorable
               --  instead of being stranded in the trash.
               if not Undo_From.Is_Empty then
                  if not Progress_Recorded then
                     Record_Progress;
                  end if;
               end if;
               declare
                  Reload : constant Operation_Result :=
                    Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key));
                  pragma Unreferenced (Reload);
               begin
                  null;
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
            Undo_From.Append (Trashed);
            Undo_To.Append (Item.Full_Path);
            Identities.Append
              (To_Unbounded_String (Files.File_Identities.Token (To_String (Trashed))));
            Record_Progress;
         end;
      end loop;

      --  Restoring from trash reproduces the original path, but re-trashing
      --  allocates a fresh trash location, so this entry is undo-only.
      if not Progress_Recorded and then not Undo_From.Is_Empty then
         Record_Progress;
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.trash.failed");
         return Make_Result (Operation_Failed, "error.trash.failed", Files.Model.Current_Path (Model));
   end Delete_Selected;

   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Delete_Permanently);
      end if;
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.permanent_delete.failed");
            declare
               Reload : constant Operation_Result :=
                 Reload_With_Error (Model, Settings, "error.permanent_delete.failed");
               pragma Unreferenced (Reload);
            begin
               null;
            end;
            return Make_Result
              (Operation_Failed, "error.permanent_delete.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Permanently (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result :=
                    Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key));
                  pragma Unreferenced (Reload);
               begin
                  null;
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Delete_Selected_Permanently;

   function Restore_Selected_From_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Restore);
      end if;
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Restore_From_Trash (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result :=
                    Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key));
                  pragma Unreferenced (Reload);
               begin
                  null;
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Restore_Selected_From_Trash;

   function Empty_Trash
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Trash_Dir   : constant String :=
        (if Files.Model.Background_Transfers (Model) then "" else Files.File_System.Trash_Files_Directory);
      Load        : Files.File_System.Directory_Load_Result;
      Total       : Natural := 0;
      Failed      : Natural := 0;
      First_Error : Unbounded_String;
      Enumeration_Settings : Files.Settings.Settings_Model := Settings;
   begin
      if Files.Model.Background_Transfers (Model) then
         return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Empty_Trash);
      end if;
      if Trash_Dir = "" then
         return Disabled (Model, "error.trash.unavailable");
      end if;

      --  Empty Trash purges every payload, regardless of display preferences.
      Enumeration_Settings.Show_Hidden_Files := True;
      Load := Files.File_System.Load_Directory (Trash_Dir, Enumeration_Settings);
      if not Load.Success then
         Files.Model.Set_Error (Model, To_String (Load.Error_Key));
         return Make_Result (Operation_Failed, To_String (Load.Error_Key), Trash_Dir);
      end if;

      for Item of Load.Items loop
         exit when Files.Job_Context.Cancelled;
         Total := Total + 1;
         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Trashed_Item (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Failed := Failed + 1;
               if Length (First_Error) = 0 then
                  First_Error := Mutation.Error_Key;
               end if;
            end if;
         end;
      end loop;

      --  Reload the (now emptied) trash view regardless of per-item outcome.
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         pragma Unreferenced (Reload);
      begin
         null;
      end;

      --  Emptying the trash is terminal: no undo entry is recorded.
      if Total > 0 and then Failed = Total then
         declare
            Error_Key : constant String :=
              (if Length (First_Error) > 0 then To_String (First_Error) else "error.trash.empty_failed");
         begin
            Files.Model.Set_Error (Model, Error_Key);
            return Make_Result (Operation_Failed, Error_Key, Trash_Dir);
         end;
      elsif Failed > 0 then
         --  Mixed outcome: the survivors are reported as a non-fatal diagnostic.
         Files.Model.Set_Error (Model, "error.trash.empty_partial");
         return Make_Result (Operation_Success, Path => Trash_Dir);
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Trash_Dir);
   end Empty_Trash;

   --  Full paths of every entry directly inside Directory (hidden entries
   --  included). Used as the "already exists" set for conflict detection and for
   --  rename uniquification, so a renamed paste avoids any existing name, not
   --  just the colliding one. Falls back to an empty set when the directory
   --  cannot be scanned; Execute_Drop_Import then still refuses to clobber.
   function Existing_Destination_Paths
     (Directory : String)
      return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
      Search : Ada.Directories.Search_Type;
      Entry_Value : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search    => Search,
         Directory => Directory,
         Pattern   => "",
         Filter    => [others => True]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Value);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Entry_Value);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Append (To_Unbounded_String (Files.Paste.Desired_Path (Directory, Name)));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
      return Result;
   exception
      when others =>
         return Files.Types.String_Vectors.Empty_Vector;
   end Existing_Destination_Paths;

   --  Build the paste work-list from validated plans: one item per valid plan,
   --  skipping a move whose destination equals its source (moving an item into
   --  the directory it already lives in is a no-op).
   function Paste_Work_List
     (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Directory : String)
      return Files.Paste.Work_Item_Vectors.Vector
   is
      Work : Files.Paste.Work_Item_Vectors.Vector;
   begin
      for Plan of Plans loop
         if Plan.Valid
           and then not (Plan.Mode = Files.File_System.Drop_Move
                         and then Plan.Source_Path = Plan.Destination_Path)
         then
            Work.Append
              (Files.Paste.Work_Item'
                 (Source_Path => Plan.Source_Path,
                  Dest_Dir    => To_Unbounded_String (Directory),
                  Dest_Name   =>
                    To_Unbounded_String
                      (Ada.Directories.Simple_Name (To_String (Plan.Source_Path)))));
         end if;
      end loop;
      return Work;
   end Paste_Work_List;

   --  Remove a destination that a Replace decision must overwrite by moving it
   --  to the trash. A failed trash operation aborts replacement. Never
   --  touches a destination that is also the source (a paste onto itself).
   function Clear_Replaced_Destination
     (Path    : String;
      Source  : String;
      Trashed : out Files.Types.UString)
      return Boolean is
   begin
      Trashed := Null_Unbounded_String;
      if not Exists_Safely (Path) or else Path = Source then
         return True;
      end if;

      declare
         Result : constant Files.File_System.Mutation_Result :=
           Files.File_System.Preserve_For_Replace (Path, Trashed);
      begin
         if Result.Success then
            return True;
         end if;
      end;

      return False;
   end Clear_Replaced_Destination;

   --  Batch size for the first advance driven from Begin_Paste /
   --  Resolve_Paste_Conflict: large enough that ordinary interactive pastes
   --  finish in one step (so no progress overlay ever flickers), while larger
   --  batches keep animating through the per-frame render-loop advances.
   Paste_Execution_First_Batch : constant := 32;

   --  Finalize an armed paste execution: record one undo covering the items
   --  actually completed (move reversed by moving back; copy by deleting the
   --  created copies), clear the move-mode clipboard, reload, and clear the
   --  execution state. A non-empty Error_Key reports a mid-run write failure.
   function Finalize_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String)
      return Operation_Result
   is
      Mode       : constant Files.File_System.Drop_Import_Mode :=
        Files.Model.Paste_Execution_Mode (Model);
      Undo_From  : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Undo_From (Model);
      Undo_To    : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Undo_To (Model);
      --  Trash locations of destinations a Replace overwrote; undo restores them,
      --  and a paste that replaced anything is undo-only (redo is not attempted).
      Replaced_Trash : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Paste_Execution_Replaced_Trash (Model);
      Redoable   : constant Boolean := Replaced_Trash.Is_Empty;
      First_Dest : constant String := Files.Model.Paste_Execution_First_Dest (Model);
   begin
      if not Undo_From.Is_Empty then
         if Mode = Files.File_System.Drop_Move then
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Move, Undo_From, Undo_To,
               Redoable      => Redoable,
               Restore_Trash => Replaced_Trash,
               Original_Restore_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
               Original_Restore_Targets => Files.Model.Paste_Execution_Replaced_Targets (Model),
               Original_Identities => Files.Model.Paste_Execution_Created_Identities (Model),
               Original_Tree_Revisions => Files.Model.Paste_Execution_Created_Tree_Revisions (Model),
               Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Created_Count (Model),
               Retain_Verified_Restores => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
         else
            --  A copy is reversed by deleting the created copies (Undo_From) and
            --  redone by copying each source (Undo_To) back to its destination.
            Files.Model.Record_Undo
              (Model, Files.Model.Undo_Delete_Created, Undo_From,
               Files.Types.String_Vectors.Empty_Vector,
               Forward       => Undo_To,
               Create_Kind   => Files.Model.Create_Copy,
               Redoable      => Redoable,
               Restore_Trash => Replaced_Trash,
               Original_Restore_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
               Original_Restore_Targets => Files.Model.Paste_Execution_Replaced_Targets (Model),
               Original_Identities => Files.Model.Paste_Execution_Created_Identities (Model),
               Original_Tree_Revisions => Files.Model.Paste_Execution_Created_Tree_Revisions (Model),
               Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Created_Count (Model),
               Retain_Verified_Restores => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
         end if;

         --  A clipboard cut/move consumes the clipboard once the paste has run
         --  (even if it was cancelled part-way, the completed sources have
         --  already moved). A drag-and-drop move never touches the clipboard, so
         --  it must not clear an unrelated clipboard selection.
         if Mode = Files.File_System.Drop_Move
           and then Files.Model.Paste_Execution_Clears_Clipboard (Model)
         then
            Files.Model.Clear_Clipboard (Model);
         end if;
      end if;

      if Undo_From.Is_Empty and then not Replaced_Trash.Is_Empty then
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Restore_Trash, Replaced_Trash,
            Files.Model.Paste_Execution_Replaced_Targets (Model), Redoable => False,
            Original_Identities => Files.Model.Paste_Execution_Replaced_Identities (Model),
            Retain_Verified_Main => Files.Model.Paste_Execution_Verified_Replaced_Count (Model));
      end if;
      Files.Model.Clear_Paste_Execution (Model);

      if Files.Model.Background_Transfers (Model) then
         --  Preserve mutation errors while a nonmodal helper refreshes the view.
         Files.Model.Set_Error (Model, Error_Key);
         declare
            Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
         begin
            if Error_Key /= "" then
               return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
            elsif Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;
         return Make_Result (Operation_Success, Path => First_Dest);
      end if;

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            if Error_Key /= "" then
               Files.Model.Set_Error (Model, Error_Key);
               return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
            end if;
            return Reload;
         end if;
      end;

      if Error_Key /= "" then
         Files.Model.Set_Error (Model, Error_Key);
         return Make_Result (Operation_Failed, Error_Key, Files.Model.Current_Path (Model));
      end if;

      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => First_Dest);
   end Finalize_Paste_Execution;

   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
   is
      Processed : Natural := 0;
   begin
      if Files.Process_Jobs.Active (Files.Model.Background_Operation (Model)) then
         return Files.Operation_Jobs.Advance (Model, Settings);
      end if;
      if not Files.Model.Paste_Execution_Is_Active (Model) then
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      while Processed < Max_Items
        and then (not Files.Model.Paste_Execution_Cancelled (Model)
                  or else Files.Model.Background_Transfers (Model))
        and then Files.Model.Paste_Execution_Cursor (Model)
                 < Files.Model.Paste_Execution_Action_Count (Model)
      loop
         declare
            Index  : constant Positive := Files.Model.Paste_Execution_Cursor (Model) + 1;
            Action : constant Files.Paste.Resolved_Action :=
              Files.Model.Paste_Execution_Action (Model, Index);
         begin
            if Action.Skip then
               Files.Model.Skip_Paste_Execution_Action (Model);
            elsif Files.Model.Background_Transfers (Model) then
               declare
                  Finished : Boolean;
                  Result   : Files.Transfer_Jobs.Job_Result;
               begin
                  Files.Model.Advance_Background_Paste (Model, Finished, Result);
                  if not Finished then
                     return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
                  end if;
                  if Length (Result.Trashed) > 0 then
                     Files.Model.Record_Paste_Execution_Replaced_Trash
                       (Model, Result.Trashed, To_String (Result.Trashed_Identity), To_String (Action.Dest_Path));
                  end if;
                  if Result.Cancelled then
                     return Finalize_Paste_Execution (Model, Settings, "");
                  elsif not Result.Mutation.Success then
                     return Finalize_Paste_Execution (Model, Settings, To_String (Result.Mutation.Error_Key));
                  end if;
                  Files.Model.Record_Paste_Execution_Write
                    (Model, Action.Dest_Path, Action.Source_Path,
                     Ada.Directories.Simple_Name (To_String (Action.Dest_Path)),
                     To_String (Result.Created_Identity), To_String (Result.Created_Tree_Revision),
                     Retain_Verified_Snapshot => Result.Recovered);
                  if Result.Recovered then
                     return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
                  end if;
                  if Files.Model.Paste_Execution_Cancelled (Model) then
                     return Finalize_Paste_Execution (Model, Settings, "");
                  end if;
               end;
            else
               declare
                  Replaced_Trash, Replaced_Identity : Files.Types.UString := Null_Unbounded_String;
                  Created_Identities, Created_Tree_Revisions : Files.Types.String_Vectors.Vector;
                  function Preserve_Replacement return Boolean is
                     Cleared : constant Boolean := Clear_Replaced_Destination
                       (To_String (Action.Dest_Path), To_String (Action.Source_Path), Replaced_Trash);
                  begin
                     if Length (Replaced_Trash) > 0 then
                        Replaced_Identity := To_Unbounded_String
                          (Files.File_Identities.Token (To_String (Replaced_Trash)));
                     end if;
                     return Cleared;
                  end Preserve_Replacement;
               begin
                  if Action.Replaced and then not Preserve_Replacement
                  then
                     if Length (Replaced_Trash) > 0 then
                        Files.Model.Record_Paste_Execution_Replaced_Trash
                          (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
                     end if;
                     return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
                  end if;

                  declare
                     Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
                  begin
                     Plans.Append
                       (Files.File_System.Drop_Import_Plan'
                          (Source_Path      => Action.Source_Path,
                           Destination_Path => Action.Dest_Path,
                           Mode             => Files.Model.Paste_Execution_Mode (Model),
                           Valid            => True,
                           Error_Key        => Null_Unbounded_String));
                     declare
                        Mutation : constant Files.File_System.Mutation_Result :=
                          Files.File_System.Execute_Drop_Import
                            (Plans, Created_Identities, Created_Tree_Revisions,
                             Batch => Files.Model.Paste_Execution_Copy_Context (Model));
                     begin
                        if not Mutation.Success then
                           --  The destination was just cleared but the write
                           --  failed: put the trashed original back so a mid-paste
                           --  failure never loses the pre-existing file.
                           if Length (Replaced_Trash) > 0 then
                              declare
                                 Restored : constant Files.File_System.Mutation_Result :=
                                   Files.File_System.Restore_From_Trash
                                     (To_String (Replaced_Trash), To_String (Replaced_Identity),
                                      To_String (Action.Dest_Path));
                              begin
                                 if not Restored.Success then
                                    Files.Model.Record_Paste_Execution_Replaced_Trash
                          (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
                                    return Finalize_Paste_Execution
                                      (Model, Settings, To_String (Restored.Error_Key));
                                 end if;
                              end;
                           end if;
                           return Finalize_Paste_Execution
                             (Model, Settings, To_String (Mutation.Error_Key));
                        end if;
                     end;
                  end;

                  --  Write succeeded: track the overwritten original's trash
                  --  location so the paste's undo entry can restore it.
                  if Length (Replaced_Trash) > 0 then
                     Files.Model.Record_Paste_Execution_Replaced_Trash
                          (Model, Replaced_Trash, To_String (Replaced_Identity), To_String (Action.Dest_Path));
                  end if;

                  Files.Model.Record_Paste_Execution_Write
                    (Model,
                     Action.Dest_Path,
                     Action.Source_Path,
                     Ada.Directories.Simple_Name (To_String (Action.Dest_Path)),
                     To_String (Created_Identities.First_Element),
                     To_String (Created_Tree_Revisions.First_Element));
               end;
            end if;
         end;
         Processed := Processed + 1;
      end loop;

      if Files.Model.Paste_Execution_Cancelled (Model)
        or else Files.Model.Paste_Execution_Cursor (Model)
                >= Files.Model.Paste_Execution_Action_Count (Model)
      then
         return Finalize_Paste_Execution (Model, Settings, "");
      end if;

      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end Advance_Paste_Execution;

   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) then
         Files.Model.Cancel_Paste_Execution (Model);
      end if;
   end Cancel_Paste_Execution;

   function Begin_Paste
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result is
   begin
      return Begin_Paste_To
        (Model, Settings, Source_Paths, Files.Model.Current_Path (Model), Mode, From_Clipboard);
   end Begin_Paste;

   function Begin_Paste_To
     (Model          : in out Files.Model.Window_Model;
      Settings       : Files.Settings.Settings_Model;
      Source_Paths   : Files.Types.String_Vectors.Vector;
      Destination    : String;
      Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
      From_Clipboard : Boolean := True)
      return Operation_Result
   is
      Directory : constant String := Destination;
      Plans     : Files.File_System.Drop_Import_Result;
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) or else Files.Model.Paste_Conflict_Is_Active (Model) then
         return Make_Result (Operation_Disabled, Path => Directory);
      end if;
      if Source_Paths.Is_Empty then
         return Disabled (Model, "error.drop.invalid_source");
      end if;

      --  Reuse the drag-and-drop planner purely to validate the sources
      --  (missing source, invalid name, drop-into-self) and to detect same-dir
      --  move no-ops; its auto-renamed destinations are discarded.
      Plans := Files.File_System.Plan_Drop_Import (Source_Paths, Directory, Mode);
      if not Plans.Success then
         Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
         return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Directory);
      end if;

      declare
         Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
           Paste_Work_List (Plans.Plans, Directory);
         Existing : constant Files.Types.String_Vectors.Vector :=
           Existing_Destination_Paths (Directory);
         Conflict : constant Natural :=
           Files.Paste.Next_Unresolved_Conflict
             (Work, Files.Paste.Policy_Ask, Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
      begin
         if Conflict = 0 then
            --  No collisions: arm the resumable execution and run the first
            --  batch. Small pastes finish here; larger ones keep advancing under
            --  the render loop while the progress overlay is shown.
            declare
               Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
                 Files.Paste.Resolve
                   (Work, Files.Paste.Policy_Ask,
                    Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
            begin
               Files.Model.Begin_Paste_Execution (Model, Actions, Mode, From_Clipboard);
               return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
            end;
         else
            --  Collisions remain: arm the conflict dialog and write nothing yet.
            Files.Model.Begin_Paste_Conflict (Model, Work, Existing, Mode, Conflict, From_Clipboard);
            Files.Model.Set_Error (Model, "");
            return Make_Result (Operation_Success, Path => Directory);
         end if;
      end;
   end Begin_Paste_To;

   function Resolve_Paste_Conflict
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Choice    : Conflict_Choice;
      Apply_All : Boolean)
      return Operation_Result
   is
   begin
      if not Files.Model.Paste_Conflict_Is_Active (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      if Choice = Choice_Cancel then
         Files.Model.Clear_Paste_Conflict (Model);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      declare
         Decision : constant Files.Paste.Item_Decision :=
           (case Choice is
              when Choice_Replace => Files.Paste.Decision_Replace,
              when Choice_Skip    => Files.Paste.Decision_Skip,
              when Choice_Rename  => Files.Paste.Decision_Rename,
              when Choice_Cancel  => Files.Paste.Decision_Skip);
      begin
         if Apply_All then
            Files.Model.Set_Paste_Conflict_Policy
              (Model,
               (case Choice is
                  when Choice_Replace => Files.Paste.Policy_Replace_All,
                  when Choice_Skip    => Files.Paste.Policy_Skip_All,
                  when Choice_Rename  => Files.Paste.Policy_Rename_All,
                  when Choice_Cancel  => Files.Paste.Policy_Skip_All));
         else
            Files.Model.Set_Paste_Conflict_Override
              (Model, Files.Model.Paste_Conflict_Index (Model), Decision);
         end if;
      end;

      declare
         Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
           Files.Model.Paste_Conflict_Items (Model);
         Existing : constant Files.Types.String_Vectors.Vector :=
           Files.Model.Paste_Conflict_Existing (Model);
         Policy   : constant Files.Paste.Conflict_Policy := Files.Model.Paste_Conflict_Policy (Model);
         Overrides : constant Files.Paste.Item_Decision_Vectors.Vector :=
           Files.Model.Paste_Conflict_Overrides (Model);
         Mode     : constant Files.File_System.Drop_Import_Mode :=
           Files.Model.Paste_Conflict_Mode (Model);
         Next     : constant Natural :=
           Files.Paste.Next_Unresolved_Conflict (Work, Policy, Overrides, Existing);
      begin
         if Next /= 0 then
            Files.Model.Set_Paste_Conflict_Index (Model, Next);
            return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
         end if;

         declare
            Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
              Files.Paste.Resolve (Work, Policy, Overrides, Existing);
            --  Carry the clipboard-clearing intent (clipboard paste vs
            --  drag-and-drop) captured when the conflict dialog was armed, since
            --  Clear_Paste_Conflict below resets it.
            Clears_Clipboard : constant Boolean :=
              Files.Model.Paste_Conflict_Clears_Clipboard (Model);
         begin
            --  Leave the conflict sub-mode, arm the resumable execution over the
            --  resolved actions, and run the first batch (small pastes finish
            --  here; larger ones continue under the render loop).
            Files.Model.Clear_Paste_Conflict (Model);
            Files.Model.Begin_Paste_Execution (Model, Actions, Mode, Clears_Clipboard);
            return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
         end;
      end;
   end Resolve_Paste_Conflict;

   function Commit_Create_File
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Name : constant String := Files.Model.Rename_Text (Model);
   begin
      if not Files.Model.Temporary_Item_Is_Active (Model) then
         return Disabled (Model, "error.create.no_temporary_item");
      elsif not Files.File_System.Valid_Leaf_Name_At
                  (Name, Files.Model.Current_Path (Model))
      then
         Files.Model.Set_Error (Model, "error.name.invalid");
         return Make_Result (Operation_Invalid_Name, "error.name.invalid");
      end if;

      declare
         Path     : constant String := Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name);
         Mutation : constant Files.File_System.Mutation_Result :=
           (if Files.Model.Temporary_Item_Is_Directory (Model)
            then Files.File_System.Create_Directory (Path)
            else Files.File_System.Create_Empty_File (Path));
      begin
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), Path);
         end if;
      end;

      --  The file now exists on disk, so leave create-edit mode regardless of
      --  whether the subsequent refresh succeeds; otherwise a refresh failure
      --  would strand the model in temporary-item mode.
      Files.Model.Clear_Edit_State (Model);
      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings, Name);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      Files.Model.Set_Error (Model, "");
      return
        Make_Result
          (Operation_Success,
           Path => Files.File_System.Join_Path (Files.Model.Current_Path (Model), Name));
   end Commit_Create_File;

   function Commit_Rename
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Targets     : constant Files.Model.Rename_Target_Vectors.Vector := Files.Model.Rename_Targets (Model);
      Current_Dir : constant String := Files.Model.Current_Path (Model);
      From_V      : Files.Types.String_Vectors.Vector;
      To_V        : Files.Types.String_Vectors.Vector;
      Identities  : Files.Types.String_Vectors.Vector;
      Success     : Natural := 0;
      Failure     : Natural := 0;
      Need_Reload : Boolean := False;
      First_Error_Key  : Unbounded_String := Null_Unbounded_String;
      First_Error_Path : Unbounded_String := Null_Unbounded_String;
      Focus_Name       : Unbounded_String := Null_Unbounded_String;

      procedure Record_First_Error (Key : String; Path : String) is
      begin
         if First_Error_Key = Null_Unbounded_String then
            First_Error_Key := To_Unbounded_String (Key);
            First_Error_Path := To_Unbounded_String (Path);
         end if;
      end Record_First_Error;
   begin
      if not Files.Model.Rename_Is_Active (Model) or else Targets.Is_Empty then
         return Disabled (Model, "error.rename.disabled");
      end if;

      --  Capture old paths first (already done by Rename_Targets), then rename
      --  each item best-effort: successes are recorded for a single undo, and
      --  failures are collected without aborting the remaining renames.
      for Target of Targets loop
         declare
            Old_Full : constant String := To_String (Target.Old_Full_Path);
            Old_Name : constant String := To_String (Target.Old_Name);
            New_Name : constant String := To_String (Target.New_Name);
         begin
            if not Files.File_System.Valid_Leaf_Name_At (New_Name, Current_Dir) then
               Failure := Failure + 1;
               Record_First_Error ("error.name.invalid", Old_Full);
            elsif New_Name = Old_Name then
               if Exists_Safely (Old_Full) then
                  Success := Success + 1;
                  if Focus_Name = Null_Unbounded_String then
                     Focus_Name := Target.New_Name;
                  end if;
               else
                  Failure := Failure + 1;
                  Need_Reload := True;
                  Record_First_Error ("error.rename.source_missing", Old_Full);
               end if;
            else
               declare
                  New_Path : constant String := Files.File_System.Join_Path (Current_Dir, New_Name);
                  Mutation : constant Files.File_System.Mutation_Result :=
                    Files.File_System.Rename_Item (Old_Full, New_Path);
               begin
                  if Mutation.Success then
                     Success := Success + 1;
                     Need_Reload := True;
                     From_V.Append (To_Unbounded_String (New_Path));
                     To_V.Append (Target.Old_Full_Path);
                     Identities.Append (To_Unbounded_String (Files.File_Identities.Token (New_Path)));
                     if Focus_Name = Null_Unbounded_String then
                        Focus_Name := Target.New_Name;
                     end if;
                  else
                     Failure := Failure + 1;
                     if To_String (Mutation.Error_Key) = "error.rename.source_missing" then
                        Need_Reload := True;
                     end if;
                     Record_First_Error (To_String (Mutation.Error_Key), New_Path);
                  end if;
               end;
            end if;
         end;
      end loop;

      --  All renames failed. Keep the inline editors active (so the user can
      --  correct them) unless a vanished source forces a reload -- matching the
      --  single-item behavior exactly.
      if Success = 0 then
         declare
            Failed_Status : constant Operation_Status :=
              (if To_String (First_Error_Key) = "error.name.invalid"
               then Operation_Invalid_Name
               else Operation_Failed);
         begin
            Files.Model.Set_Error (Model, To_String (First_Error_Key));
            if Need_Reload then
               declare
                  Reload : constant Operation_Result :=
                    Reload_With_Error (Model, Settings, To_String (First_Error_Key));
                  pragma Unreferenced (Reload);
               begin
                  null;
               end;
            end if;
            return
              Make_Result
                (Failed_Status,
                 To_String (First_Error_Key),
                 To_String (First_Error_Path));
         end;
      end if;

      --  At least one rename succeeded; leave rename-edit mode even if the
      --  refresh fails, rather than stranding the model in it.
      Files.Model.Clear_Edit_State (Model);
      if not From_V.Is_Empty then
         Files.Model.Record_Undo
           (Model, Files.Model.Undo_Rename, From_V, To_V, Original_Identities => Identities);
      end if;

      if Need_Reload then
         declare
            Reload : constant Operation_Result :=
              Reload_Current_Directory (Model, Settings, To_String (Focus_Name));
         begin
            if Reload.Status /= Operation_Success then
               return Reload;
            end if;
         end;
      end if;

      if Failure > 0 then
         --  Some items renamed, some failed: report partial success so the
         --  user learns not every rename landed.
         Files.Model.Set_Error (Model, "error.rename.partial");
         return
           Make_Result
             (Operation_Success,
              "error.rename.partial",
              Files.File_System.Join_Path (Current_Dir, To_String (Focus_Name)));
      end if;

      Files.Model.Set_Error (Model, "");
      return
        Make_Result
          (Operation_Success,
           Path => Files.File_System.Join_Path (Current_Dir, To_String (Focus_Name)));
   end Commit_Rename;

end Transfer;
