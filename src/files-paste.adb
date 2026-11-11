with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Files.Leaf_Names;
with Hostkit.Fs;

package body Files.Paste is

   --  The effective per-item decision for a policy and an optional override.
   --  An explicit override wins; otherwise the policy maps to a decision
   --  (Policy_Ask stays Decision_Pending).
   --
   --  @param Policy Batch-wide policy.
   --  @param Override Per-item override (Decision_Pending when none).
   --  @return The decision that applies to the item.
   function Effective_Decision
     (Policy   : Conflict_Policy;
      Override : Item_Decision)
      return Item_Decision;

   use Ada.Strings.Unbounded;

   package Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   package Spelling_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   function To_Set
     (Paths : Files.Types.String_Vectors.Vector)
      return Path_Sets.Set
   is
      Result : Path_Sets.Set;
   begin
      for Path of Paths loop
         Result.Include (To_String (Path));
      end loop;
      return Result;
   end To_Set;

   function Desired_Path
     (Dir  : String;
      Name : String)
      return String is
   begin
      --  The host's separator, so the path is spelled as a listing spells
      --  it: labels, favorites and recents follow a moved item by its path.
      return Hostkit.Fs.Join (Dir, Name);
   end Desired_Path;

   function Effective_Decision
     (Policy   : Conflict_Policy;
      Override : Item_Decision)
      return Item_Decision is
   begin
      if Override /= Decision_Pending then
         return Override;
      end if;

      case Policy is
         when Policy_Ask         => return Decision_Pending;
         when Policy_Replace_All => return Decision_Replace;
         when Policy_Skip_All    => return Decision_Skip;
         when Policy_Rename_All  => return Decision_Rename;
      end case;
   end Effective_Decision;

   --  The override recorded for a one-based item index, or Decision_Pending when
   --  the overrides vector is shorter than the index.
   function Override_At
     (Overrides : Item_Decision_Vectors.Vector;
      Index     : Positive)
      return Item_Decision is
   begin
      if Index <= Natural (Overrides.Length) then
         return Overrides.Element (Index);
      end if;
      return Decision_Pending;
   end Override_At;

   function Next_Unresolved_Conflict
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      After     : Natural := 0)
      return Natural is
      Existing_Set : constant Path_Sets.Set := To_Set (Existing);
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         if Index > After
           and then Existing_Set.Contains
             (Desired_Path
                (To_String (Items.Element (Index).Dest_Dir),
                 To_String (Items.Element (Index).Dest_Name)))
           and then Effective_Decision (Policy, Override_At (Overrides, Index)) = Decision_Pending
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Next_Unresolved_Conflict;

   function First_Free_Name
     (Name      : String;
      Taken     : not null access function (Leaf : String) return Boolean;
      Dos_Rules : Boolean := False)
      return String
   is
      Stem      : constant String := Files.Types.Stem_Of (Name);
      Extension : constant String :=
        (if Files.Types.Extension_Of (Name) = "" then "" else "." & Files.Types.Extension_Of (Name));
   begin
      if not Taken (Name) then
         return Name;
      end if;
      for Counter in 2 .. Positive'Last loop
         declare
            Counted   : constant String := " " & Files.Types.Natural_Text (Counter);
            --  A long name is cut down, never made longer than the
            --  destination stores; an extension too long to keep with it
            --  goes by Fit's rule instead.
            Shortened : constant String :=
              Files.Leaf_Names.Cut (Stem, Counted & Extension, Files.Leaf_Names.Max_Length, Dos_Rules);
            Candidate : constant String :=
              (if not Files.Leaf_Names.Too_Long_Under (Shortened, Dos_Rules) then Shortened
               else Files.Leaf_Names.Fit (Name, Files.Leaf_Names.Max_Length, Dos_Rules, Insert => Counted));
         begin
            if not Taken (Candidate) then
               return Candidate;
            end if;
         end;
      end loop;
      return Name;
   end First_Free_Name;

   --  A destination path derived from Desired that collides with neither
   --  Existing nor Claimed, formed by inserting " N" before the extension. This
   --  mirrors Files.File_System.Plan_Drop_Import's Available_Destination so
   --  renamed pastes match drag-and-drop's numbering.
   function Unique_Path
     (Dir      : String;
      Name     : String;
      Existing : Path_Sets.Set;
      Claimed  : Path_Sets.Set;
      Fold     : Boolean;
      Dos      : Boolean)
      return String
   is
      function Key (Path : String) return String is
        (if Fold then Files.Types.Fold_Case (Path) else Path);

      function Taken (Leaf : String) return Boolean is
        (Existing.Contains (Key (Desired_Path (Dir, Leaf)))
         or else Claimed.Contains (Key (Desired_Path (Dir, Leaf))));
   begin
      return Desired_Path (Dir, First_Free_Name (Name, Taken'Access, Dos));
   end Unique_Path;

   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Fold_Names : Boolean := False;
      Dos_Names  : Boolean := False)
      return Resolved_Action_Vectors.Vector
   is
      --  The name a set holds a path under: folded where the destination
      --  folds case, so Readme.md and README.md are one destination there.
      function Key (Path : String) return String is
        (if Fold_Names then Files.Types.Fold_Case (Path) else Path);

      function Key_Set return Path_Sets.Set is
         Result : Path_Sets.Set;
      begin
         for Path of Existing loop
            Result.Include (Key (To_String (Path)));
         end loop;
         return Result;
      end Key_Set;

      --  Where names fold, the existing entry's own spelling for each key:
      --  the first listed, as later Existing paths may be incoming aliases.
      function Spellings return Spelling_Maps.Map is
         Result : Spelling_Maps.Map;
      begin
         if Fold_Names then
            for Path of Existing loop
               if not Result.Contains (Key (To_String (Path))) then
                  Result.Insert (Key (To_String (Path)), To_String (Path));
               end if;
            end loop;
         end if;
         return Result;
      end Spellings;

      Actions : Resolved_Action_Vectors.Vector;
      Existing_Set : constant Path_Sets.Set := Key_Set;
      Existing_Spelling : constant Spelling_Maps.Map := Spellings;

      --  A replace writes over the existing entry under its own name, as a
      --  folding filesystem keeps it: Report.txt over report.txt stays
      --  report.txt, and Undo puts the original back under that name.
      function Replace_Target (Desired : String) return String is
        (if Existing_Spelling.Contains (Key (Desired))
         then Existing_Spelling.Element (Key (Desired)) else Desired);
      --  Destinations already assigned earlier in this batch; a second item that
      --  would resolve to the same path is uniquified so it cannot clobber the
      --  first even before either is written to disk.
      Claimed : Path_Sets.Set;

      procedure Emit_Write (Source : Files.Types.UString; Dest : String; Replaced : Boolean) is
      begin
         Actions.Append
           (Resolved_Action'
              (Source_Path => Source,
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => Replaced));
         Claimed.Include (Key (Dest));
      end Emit_Write;
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         declare
            Item     : constant Work_Item := Items.Element (Index);
            Dir      : constant String := To_String (Item.Dest_Dir);
            Name     : constant String := To_String (Item.Dest_Name);
            Desired  : constant String := Desired_Path (Dir, Name);
            Conflict : constant Boolean := Existing_Set.Contains (Key (Desired));
         begin
            if not Conflict then
               --  No on-disk conflict: write to the desired name, but still
               --  uniquify against earlier same-batch claims to avoid clobber.
               if Claimed.Contains (Key (Desired)) then
                  Emit_Write
                    (Item.Source_Path,
                     Unique_Path (Dir, Name, Existing_Set, Claimed, Fold_Names, Dos_Names), False);
               else
                  Emit_Write (Item.Source_Path, Desired, False);
               end if;
            else
               case Effective_Decision (Policy, Override_At (Overrides, Index)) is
                  when Decision_Replace =>
                     --  Only the first item may replace the existing entry. A
                     --  later same-named item would otherwise replace the copy
                     --  this batch just wrote (sending it to the trash) and
                     --  leave Undo two entries for one path; keep both instead.
                     if Claimed.Contains (Key (Desired)) then
                        Emit_Write
                          (Item.Source_Path,
                           Unique_Path (Dir, Name, Existing_Set, Claimed, Fold_Names, Dos_Names), False);
                     else
                        Emit_Write (Item.Source_Path, Replace_Target (Desired), True);
                     end if;
                  when Decision_Rename =>
                     Emit_Write
                       (Item.Source_Path,
                        Unique_Path (Dir, Name, Existing_Set, Claimed, Fold_Names, Dos_Names), False);
                  when Decision_Skip | Decision_Pending =>
                     --  Skip, and treat an undecided conflict as Skip so the
                     --  destination is never silently overwritten.
                     Actions.Append
                       (Resolved_Action'
                          (Source_Path => Item.Source_Path,
                           Dest_Path   => To_Unbounded_String (Desired),
                           Skip        => True,
                           Replaced    => False));
               end case;
            end if;
         end;
      end loop;
      return Actions;
   end Resolve;

end Files.Paste;
