with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Files.Paste;
separate (Files.File_System)
function Plan_Drop_Import
  (Source_Paths          : Files.Types.String_Vectors.Vector;
   Destination_Directory : String;
   Mode                  : Drop_Import_Mode := Drop_Copy)
   return Drop_Import_Result
is
   package Claimed_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");

   Result : Drop_Import_Result :=
     (Success   => False,
      Plans     => Drop_Import_Plan_Vectors.Empty_Vector,
      Error_Key => Null_Unbounded_String);
   --  Destinations already assigned earlier in this batch. They do not yet
   --  exist on disk, so without tracking them two sources sharing a simple
   --  name (from different directories) would resolve to the same target and
   --  the second would silently overwrite the first.
   Claimed : Claimed_Sets.Set;
   --  Whether the destination folds case: Report.txt and report.txt are then
   --  one destination, and the second must be renamed, not written over it.
   Folds   : Boolean := False;

   function Key (Path : String) return String is
     (if Folds then Files.Types.Fold_Case (Path) else Path);

   function Available_Destination (Leaf : String) return String is
      function Taken (Name : String) return Boolean is
        (Files.Fs_Primitives.Entry_Exists (Hostkit.Fs.Join (Destination_Directory, Name))
         or else Claimed.Contains (Key (Hostkit.Fs.Join (Destination_Directory, Name))));
   begin
      return Hostkit.Fs.Join
        (Destination_Directory,
         Files.Paste.First_Free_Name
           (Leaf, Taken'Access, Hostkit.Fs.Uses_Dos_Filename_Rules (Destination_Directory)));
   end Available_Destination;

   --  Path with its links resolved: Hostkit.Fs.Real_Path, which also follows
   --  Windows reparse points and gives the names' stored case there, where
   --  Normalize_Pathname resolves nothing.
   function Resolved_Directory (Path : String) return String is
      Real : constant String := Hostkit.Fs.Real_Path (Path);
   begin
      if Real /= "" then
         return Real;
      end if;
      return GNAT.OS_Lib.Normalize_Pathname
        (Path, Resolve_Links => True);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System");
         return "";
   end Resolved_Directory;

   function Same_Directory (Left, Right : String) return Boolean is
      Resolved_Left  : constant String := Resolved_Directory (Left);
      Resolved_Right : constant String := Resolved_Directory (Right);
   begin
      return
        (Resolved_Left /= ""
         and then Resolved_Right /= ""
         and then Resolved_Left = Resolved_Right)
        or else Hostkit.Metadata.Same_File (Left, Right);
   end Same_Directory;

   --  True when Inner is Outer itself or a descendant of Outer (normalized).
   function Is_Within_Tree (Inner : String; Outer : String) return Boolean is
      I : constant String := Resolved_Directory (Inner);
      O : constant String := Resolved_Directory (Outer);
   begin
      if Hostkit.Fs.Is_Link (Outer) then
         return False; --  Copying a link never traverses its target tree.
      elsif I = "" or else O = "" then
         return True; --  An unresolved directory relationship is not safe.
      end if;
      --  Resolve links before the boundary check. A destination alias can
      --  otherwise conceal that it points into the source tree. A root path
      --  already ends in a separator, so every longer path is beneath it.
      --  Where names fold case, C:\Data\Proj and c:\data\proj are one folder.
      if Hostkit.Fs.Is_Same_Or_Inside (I, O)
        or else (Hostkit.Fs.Folds_Name_Case (O)
                 and then Hostkit.Fs.Is_Same_Or_Inside (Files.Types.Fold_Case (I), Files.Types.Fold_Case (O)))
      then
         return True;
      end if;
      --  And by identity, whatever the spelling: Outer is the folder itself
      --  or one of Inner's ancestors.
      declare
         Ancestor : Unbounded_String := To_Unbounded_String (I);
      begin
         loop
            if Hostkit.Metadata.Same_File (To_String (Ancestor), Outer) then
               return True;
            end if;
            declare
               Parent : constant String := Files.Fs_Primitives.Parent_Directory (To_String (Ancestor));
            begin
               exit when Parent = To_String (Ancestor);
               Ancestor := To_Unbounded_String (Parent);
            end;
         end loop;
      exception
         when Ada.Directories.Use_Error | Ada.Directories.Name_Error =>
            null; --  Past the root: no ancestor is Outer.
      end;
      return False;
   end Is_Within_Tree;
begin
   if not Files.Fs_Primitives.Directory_Exists (Destination_Directory)
   then
      Result.Error_Key := To_Unbounded_String ("error.drop.invalid_destination");
      return Result;
   end if;
   Folds := Hostkit.Fs.Folds_Name_Case (Destination_Directory);

   for Source of Source_Paths loop
      declare
         Source_Text : constant String := To_String (Source);
         Leaf        : Unbounded_String;
         Plan        : Drop_Import_Plan;
      begin
         Plan.Source_Path := Source;
         Plan.Mode := Mode;
         if not Files.Fs_Primitives.Entry_Exists (Source_Text) then
            Plan.Valid := False;
            Plan.Error_Key := To_Unbounded_String ("error.drop.invalid_source");
            Result.Plans.Append (Plan);
            Result.Error_Key := Plan.Error_Key;
         else
            Leaf := To_Unbounded_String (Files.Fs_Primitives.Leaf_Text (Source_Text));
            if not Storable_Leaf_Name_At (To_String (Leaf), Destination_Directory) then
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.name.invalid");
               Result.Error_Key := Plan.Error_Key;
            elsif Is_Within_Tree (Destination_Directory, Source_Text) then
               --  Refuse to copy or move a directory into itself or one of
               --  its own descendants; Execute_Drop_Import's recursive copy
               --  would otherwise recurse without bound.
               Plan.Valid := False;
               Plan.Error_Key := To_Unbounded_String ("error.drop.into_self");
               Result.Error_Key := Plan.Error_Key;
            else
               Plan.Valid := True;
               if Mode = Drop_Move
                 and then Same_Directory
                   (Files.Fs_Primitives.Parent_Directory (Source_Text),
                    Destination_Directory)
               then
                  --  Moving an item into the directory it already lives in is
                  --  a no-op; keep its own path so Execute_Drop_Import skips
                  --  it instead of creating a numbered duplicate. (A copy
                  --  into the same directory still makes a numbered copy.)
                  Plan.Destination_Path := Source;
               else
                  Plan.Destination_Path := To_Unbounded_String (Available_Destination (To_String (Leaf)));
               end if;
               Claimed.Include (Key (To_String (Plan.Destination_Path)));
               Plan.Error_Key := Null_Unbounded_String;
            end if;
            Result.Plans.Append (Plan);
         end if;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.File_System");
            Result.Plans.Append
              (Drop_Import_Plan'
                 (Source_Path      => Source,
                  Destination_Path => Null_Unbounded_String,
                  Mode             => Mode,
                  Valid            => False,
                  Error_Key        => To_Unbounded_String ("error.drop.failed")));
            Result.Error_Key := To_Unbounded_String ("error.drop.failed");
      end;
   end loop;

   Result.Success := Length (Result.Error_Key) = 0;
   return Result;
end Plan_Drop_Import;
