with Ada.Directories;
with Ada.Strings.Fixed;
with Files.History_Journal;
with Files.File_Identities;
with Hostkit.Fs;

separate (Files.Model)
package body Undo_Redo is
   use type Ada.Directories.File_Kind;

   --  Cap the undo history so a session doing thousands of operations does not
   --  grow it without bound: each entry retains the full source and destination
   --  path lists (and permission/ownership images), so an unbounded stack pins
   --  that data for the life of the window. Past the cap the oldest entry --
   --  least likely to ever be undone -- is dropped; LIFO undo only touches the
   --  newest, so the reachable history is unaffected.
   Max_Undo_Depth : constant := 200;

   procedure Discard_Retained (Action : Undo_Entry) is
   begin
      for Payload of Action.Restore_Trash loop
         if Files.File_System.Is_Recovery_Payload (To_String (Payload)) then
            declare
               Result : constant Files.File_System.Mutation_Result :=
                 Files.File_System.Delete_Trashed_Item (To_String (Payload));
               pragma Unreferenced (Result);
            begin
               null;
            end;
         end if;
      end loop;
   end Discard_Retained;

   procedure Discard_Retained (Entries : Undo_Entry_Vectors.Vector) is
   begin
      for Action of Entries loop
         Discard_Retained (Action);
      end loop;
   end Discard_Retained;

   function Identity_Matches (Path, Expected : String) return Boolean is
   begin
      return Expected /= ""
        and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path))
        and then Files.File_Identities.Token (Path) = Expected;
   exception
      when others =>
         return False;
   end Identity_Matches;

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean) return Boolean
   is
      Is_Link : Boolean;
   begin
      if not Identity_Matches (Path, Identity) then
         return Retain_Verified and then Identity /= "";
      end if;
      Is_Link := Hostkit.Fs.Is_Link (Path);
      return
        (if Is_Link then Tree_Revision = ""
         else Tree_Revision /= ""
           and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when others =>
         return False;
   end Creation_Snapshot_Matches;

   function Tree_Revision_Or_Empty (Path : String) return String is
   begin
      return Files.File_System.Tree_Revision (Path);
   exception
      --  A creation may already be published when its snapshot is captured.
      --  Keep the operation successful, but omit unsafe Undo for this entry.
      when others =>
         return "";
   end Tree_Revision_Or_Empty;

   function Valid_Natural_Image (Value : Files.Types.UString) return Boolean is
      Text : constant String := Ada.Strings.Fixed.Trim (To_String (Value), Ada.Strings.Both);
      Parsed : Natural;
      pragma Unreferenced (Parsed);
   begin
      if Text = "" then
         return False;
      end if;
      Parsed := Natural'Value (Text);
      return True;
   exception
      when others =>
         return False;
   end Valid_Natural_Image;

   function Valid_Ownership_Image (Value : Files.Types.UString) return Boolean is
      Text : constant String := Ada.Strings.Fixed.Trim (To_String (Value), Ada.Strings.Both);
      Space : constant Natural := Ada.Strings.Fixed.Index (Text, " ");
      User, Group : Natural;
      pragma Unreferenced (User, Group);
   begin
      if Space = 0 then
         return False;
      end if;
      User := Natural'Value (Text (Text'First .. Space - 1));
      Group := Natural'Value (Text (Space + 1 .. Text'Last));
      return True;
   exception
      when others =>
         return False;
   end Valid_Ownership_Image;

   function Try_Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Retain_Verified_Main : Natural := 0;
      Retain_Verified_Restores : Natural := 0) return Boolean is
      Identities, Tree_Revisions, Restore_Identities, Restore_Targets : Files.Types.String_Vectors.Vector;
      Targets : Files.Types.String_Vectors.Vector := To;
      Kept_From, Kept_To, Kept_Forward : Files.Types.String_Vectors.Vector;
      Kept_Identities, Kept_Tree_Revisions : Files.Types.String_Vectors.Vector;
      Invalid_Main : Boolean := False;
      Invalid_Restore : Boolean := False;

      function Main_Was_Verified (Index : Positive) return Boolean is
        (Index <= Retain_Verified_Main
         and then Index <= Original_Identities.Last_Index
         and then
           (Kind /= Undo_Delete_Created
            or else Index <= Original_Tree_Revisions.Last_Index));

      function Restore_Was_Verified (Index : Positive) return Boolean is
        (Index <= Retain_Verified_Restores
         and then Index <= Original_Restore_Identities.Last_Index
         and then Index <= Original_Restore_Targets.Last_Index);

      function Payload_Is_Complete (Index : Positive) return Boolean is
      begin
         case Kind is
            when Undo_Delete_Created =>
               return not Redoable
                 or else (Create_Kind /= Create_None
                   and then Index <= Forward.Last_Index
                   and then Length (Forward (Index)) > 0);
            when Undo_Rename | Undo_Move | Undo_Restore_Trash =>
               return Index <= Targets.Last_Index
                 and then Length (Targets (Index)) > 0
                 and then (Kind /= Undo_Restore_Trash or else not Redoable);
            when Undo_Set_Permissions =>
               return Index <= Targets.Last_Index
                 and then Valid_Natural_Image (Targets (Index))
                 and then (not Redoable
                   or else (Index <= Forward.Last_Index
                     and then Valid_Natural_Image (Forward (Index))));
            when Undo_Set_Ownership =>
               return Index <= Targets.Last_Index
                 and then Valid_Ownership_Image (Targets (Index))
                 and then (not Redoable
                   or else (Index <= Forward.Last_Index
                     and then Valid_Ownership_Image (Forward (Index))));
            when Undo_None =>
               return False;
         end case;
      end Payload_Is_Complete;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Kind = Undo_None or else From.Is_Empty then
         return False;
      end if;
      if Kind in Undo_Delete_Created | Undo_Rename | Undo_Move | Undo_Restore_Trash
        | Undo_Set_Permissions | Undo_Set_Ownership
      then
         for Index in From.First_Index .. From.Last_Index loop
            Identities.Append
              ((if Index <= Original_Identities.Last_Index then Original_Identities (Index)
                else To_Unbounded_String (Files.File_Identities.Token (To_String (From (Index))))));
            Tree_Revisions.Append
              ((if Index <= Original_Tree_Revisions.Last_Index then Original_Tree_Revisions (Index)
                elsif Kind = Undo_Delete_Created then
                   To_Unbounded_String (Tree_Revision_Or_Empty (To_String (From (Index))))
                else Null_Unbounded_String));
         end loop;
      end if;

      if Kind = Undo_Restore_Trash then
         for Index in From.First_Index .. From.Last_Index loop
            if Index > Targets.Last_Index then
               Targets.Append (To_Unbounded_String (Files.File_System.Trash_Original_Path (To_String (From (Index)))));
            end if;
         end loop;
      end if;

      for Index in Restore_Trash.First_Index .. Restore_Trash.Last_Index loop
         Restore_Targets.Append
           ((if Index <= Original_Restore_Targets.Last_Index then Original_Restore_Targets (Index)
             else To_Unbounded_String (Files.File_System.Trash_Original_Path (To_String (Restore_Trash (Index))))));
         Restore_Identities.Append
           ((if Index <= Original_Restore_Identities.Last_Index then Original_Restore_Identities (Index)
             else To_Unbounded_String (Files.File_Identities.Token (To_String (Restore_Trash (Index))))));
      end loop;
      if not Restore_Trash.Is_Empty and then Redoable then
         Invalid_Restore := True;
      end if;

      for Index in Restore_Trash.First_Index .. Restore_Trash.Last_Index loop
         if Index > Restore_Identities.Last_Index
           or else Index > Restore_Targets.Last_Index
           or else Length (Restore_Targets (Index)) = 0
           or else (not Restore_Was_Verified (Index)
             and then not Identity_Matches
               (To_String (Restore_Trash (Index)), To_String (Restore_Identities (Index))))
           or else Length (Restore_Identities (Index)) = 0
         then
            Invalid_Restore := True;
         end if;
      end loop;

      for Index in From.First_Index .. From.Last_Index loop
         declare
            Valid : constant Boolean :=
              Index <= Identities.Last_Index
              and then Index <= Tree_Revisions.Last_Index
              and then Payload_Is_Complete (Index)
              and then
                (if Kind = Undo_Delete_Created
                 then Creation_Snapshot_Matches
                   (To_String (From (Index)), To_String (Identities (Index)),
                    To_String (Tree_Revisions (Index)), Main_Was_Verified (Index))
                 else (Length (Identities (Index)) > 0
                   and then (Main_Was_Verified (Index)
                     or else Identity_Matches
                       (To_String (From (Index)), To_String (Identities (Index))))));
         begin
            if Valid then
               Kept_From.Append (From (Index));
               if Kind /= Undo_Delete_Created then
                  Kept_To.Append (Targets (Index));
               end if;
               if Redoable
                 and then Kind in Undo_Delete_Created | Undo_Set_Permissions | Undo_Set_Ownership
               then
                  Kept_Forward.Append (Forward (Index));
               end if;
               Kept_Identities.Append (Identities (Index));
               Kept_Tree_Revisions.Append (Tree_Revisions (Index));
            else
               Invalid_Main := True;
            end if;
         end;
      end loop;

      --  A replacement reversal must remove or move every created destination
      --  before restoring its preserved originals. Dropping only an
      --  unverifiable member would make those steps refer to different sets.
      if Invalid_Restore or else (not Restore_Trash.Is_Empty and then Invalid_Main) then
         Kept_From.Clear;
      end if;

      Discard_Retained (Model.Redo_Stack);
      Model.Redo_Stack.Clear;
      if Kept_From.Is_Empty then
         Files.History_Journal.Save (Model);
         return False;
      end if;

      Model.Undo_Stack.Append
        (Undo_Entry'
           (Kind          => Kind,
            From          => Kept_From,
            To            => Kept_To,
            Forward       => Kept_Forward,
            Create_Kind   => Create_Kind,
            Redoable      => Redoable,
            Restore_Trash => Restore_Trash,
            Restore_Identities => Restore_Identities,
            Restore_Targets => Restore_Targets,
            Created_Identities => Kept_Identities,
            Created_Tree_Revisions => Kept_Tree_Revisions,
            others        => <>));
      while Natural (Model.Undo_Stack.Length) > Max_Undo_Depth loop
         Discard_Retained (Model.Undo_Stack.First_Element);
         Model.Undo_Stack.Delete_First;
      end loop;
      Files.History_Journal.Save (Model);
      return True;
   end Try_Record_Undo;

   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Retain_Verified_Main : Natural := 0;
      Retain_Verified_Restores : Natural := 0)
   is
      Recorded : constant Boolean := Try_Record_Undo
        (Model, Kind, From, To, Forward, Create_Kind, Redoable, Restore_Trash,
         Original_Identities, Original_Tree_Revisions,
         Original_Restore_Identities, Original_Restore_Targets,
         Retain_Verified_Main, Retain_Verified_Restores);
      pragma Unreferenced (Recorded);
   begin
      null;
   end Record_Undo;

   procedure Clear_Undo
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Discard_Retained (Model.Undo_Stack);
      Discard_Retained (Model.Redo_Stack);
      Model.Undo_Stack.Clear;
      Model.Redo_Stack.Clear;
   end Clear_Undo;

   function Undo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Undo_Stack.Is_Empty;
   end Undo_Available;

   function Redo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Redo_Stack.Is_Empty;
   end Redo_Available;

   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Undo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Undo_Stack.Last_Element;
      Model.Undo_Stack.Delete_Last;
      Found := True;
   end Take_Undo;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Redo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Redo_Stack.Last_Element;
      Model.Redo_Stack.Delete_Last;
      Found := True;
   end Take_Redo;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Redo_Stack.Append (Action);
      Files.History_Journal.Save (Model);
   end Push_Redo;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Undo_Stack.Append (Action);
      Files.History_Journal.Save (Model);
   end Push_Undo;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Undo_None;
      end if;

      return Model.Undo_Stack.Last_Element.Kind;
   end Undo_Kind_Of;

   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.From;
   end Undo_From_Paths;

   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.To;
   end Undo_To_Paths;

end Undo_Redo;
