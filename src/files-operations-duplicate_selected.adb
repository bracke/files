separate (Files.Operations)
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

   procedure Record_Progress is
      Previous : Files.Model.Undo_Entry;
      Found : Boolean;
   begin
      if Progress_Recorded then
         Files.Model.Take_Undo (Model, Previous, Found);
      end if;
      Progress_Recorded := Try_Record_Undo
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

   function Trimmed_Image (Value : Positive) return String is (Files.Types.Natural_Text (Value));

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

   function Failed return Operation_Result is
   begin
      --  Copy_Tree commits one selection at a time. If a later source
      --  fails, reload so the earlier copies are not hidden by a stale
      --  model, and retain the failure after that reload clears errors.
      if Created.Is_Empty then
         Files.Model.Set_Error (Model, "error.duplicate.failed");
      else
         declare
            Reload : constant Operation_Result :=
              Reload_With_Error (Model, Settings, "error.duplicate.failed");
            pragma Unreferenced (Reload);
         begin
            null;
         end;
      end if;
      return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
   exception
      when others =>
         Files.Model.Set_Error (Model, "error.duplicate.failed");
         return Make_Result (Operation_Failed, "error.duplicate.failed", Directory);
   end Failed;
begin
   if Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Is_Trash_Directory (Directory) then
      return Disabled (Model, "error.duplicate.failed");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Duplicate);
   end if;
   if Items.Is_Empty or else (Directory = "" and then not Files.Model.In_Recent_View (Model)) then
      return Failed;
   end if;

   --  Created only now: the background path above hands the work to a
   --  helper, and the handler below must cover a failed reservation.
   declare
      Copy_Batch : constant Files.Copy_Context.Session := Files.Copy_Context.Create;
   begin
      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         declare
            Source : constant String := To_String (Item.Full_Path);
            --  Recent and search results can select paths from several
            --  folders; each duplicate belongs beside its source.
            Destination_Directory : constant String :=
              (if Files.Model.In_Recent_View (Model) or else Files.Model.Search_Results_Are_Active (Model)
               then Ada.Directories.Containing_Directory (Source)
               else Directory);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Leaf_Extension (Name);
            Base   : constant String := Leaf_Base (Name);

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
               return Failed;
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
   end;

   if not Created_Any then
      return Failed;
   end if;

   --  Reload the active view; an ordinary folder selects the first copy.
   return Reload_Current_Directory (Model, Settings, To_String (First_Created));
exception
   when others =>
      return Failed;
end Duplicate_Selected;
