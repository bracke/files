with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Files.Name_Parts;
with Files.Text_Case;

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

   --  The name a set holds a path under: folded where the destination folds
   --  case, so Readme.md and README.md are one destination there.
   function Name_Key (Path : String; Fold_Names : Boolean) return String is
     (if Fold_Names then Files.Text_Case.Fold_Case (Path) else Path);

   --  Existing, each path under its Name_Key.
   function Key_Set (Existing : Files.Types.String_Vectors.Vector; Fold_Names : Boolean) return Path_Sets.Set is
      Result : Path_Sets.Set;
   begin
      for Path of Existing loop
         Result.Include (Name_Key (To_String (Path), Fold_Names));
      end loop;
      return Result;
   end Key_Set;

   function Next_Unresolved_Conflict
     (Items      : Work_Item_Vectors.Vector;
      Policy     : Conflict_Policy;
      Overrides  : Item_Decision_Vectors.Vector;
      Existing   : Files.Types.String_Vectors.Vector;
      After      : Natural := 0;
      Fold_Names : Boolean := False)
      return Natural is
      Existing_Set : constant Path_Sets.Set := Key_Set (Existing, Fold_Names);
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         if Index > After
           and then Existing_Set.Contains
             (Name_Key
                (Desired_Path
                   (To_String (Items.Element (Index).Dest_Dir),
                    To_String (Items.Element (Index).Dest_Name)),
                 Fold_Names))
           and then Effective_Decision (Policy, Override_At (Overrides, Index)) = Decision_Pending
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Next_Unresolved_Conflict;

   function First_Free_Name
     (Name         : String;
      Taken        : not null access function (Leaf : String) return Boolean;
      Limit        : Hostkit.Fs.Leaf_Name_Limit := Files.Leaf_Names.Default_Limit;
      Is_Directory : Boolean := False)
      return String
   is
      Free : constant String :=
        Files.Leaf_Names.First_Free
          (Files.Name_Parts.Name_Stem (Name, Is_Directory), Files.Name_Parts.Name_Extension (Name, Is_Directory),
           Files.Leaf_Names.Spaced_Number'Access, Taken, Limit);
   begin
      return (if Free = "" then Name else Free);
   end First_Free_Name;

   --  A destination path derived from Desired that collides with neither
   --  Existing nor Claimed, numbered by First_Free_Name -- the numbering a
   --  drop gives too (Files.File_System.Plan_Drop_Import).
   function Unique_Path
     (Dir          : String;
      Name         : String;
      Existing     : Path_Sets.Set;
      Claimed      : Path_Sets.Set;
      Fold         : Boolean;
      Limit        : Hostkit.Fs.Leaf_Name_Limit;
      Is_Directory : Boolean)
      return String
   is
      function Key (Path : String) return String is
        (if Fold then Files.Text_Case.Fold_Case (Path) else Path);

      function Taken (Leaf : String) return Boolean is
        (Existing.Contains (Key (Desired_Path (Dir, Leaf)))
         or else Claimed.Contains (Key (Desired_Path (Dir, Leaf))));
   begin
      return Desired_Path (Dir, First_Free_Name (Name, Taken'Access, Limit, Is_Directory));
   end Unique_Path;

   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Fold_Names : Boolean := False;
      Name_Limit : Hostkit.Fs.Leaf_Name_Limit := Files.Leaf_Names.Default_Limit)
      return Resolved_Action_Vectors.Vector
   is
      function Key (Path : String) return String is (Name_Key (Path, Fold_Names));

      --  Where names fold, the existing entry's own spelling for each key:
      --  the first listed.
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
      Existing_Set : constant Path_Sets.Set := Key_Set (Existing, Fold_Names);
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
            --  Item's name numbered free of what exists and what is claimed.
            function Numbered return String is
              (Unique_Path (Dir, Name, Existing_Set, Claimed, Fold_Names, Name_Limit, Item.Is_Directory));
         begin
            if not Conflict then
               --  No on-disk conflict: write to the desired name, but still
               --  uniquify against earlier same-batch claims to avoid clobber.
               if Claimed.Contains (Key (Desired)) then
                  Emit_Write
                    (Item.Source_Path,
                     Numbered, False);
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
                           Numbered, False);
                     else
                        Emit_Write (Item.Source_Path, Replace_Target (Desired), True);
                     end if;
                  when Decision_Rename =>
                     Emit_Write
                       (Item.Source_Path,
                        Numbered, False);
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

   function Name_Rules_Of (Directory : String) return Name_Rules is
     (if Directory = ""
      then (others => <>)
      else (Fold_Names => Hostkit.Fs.Folds_Name_Case (Directory),
            Name_Limit => Hostkit.Fs.Leaf_Name_Limit_At (Directory)));

   function Next_Unresolved_Conflict
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Rules     : Name_Rules;
      After     : Natural := 0)
      return Natural is
     (Next_Unresolved_Conflict (Items, Policy, Overrides, Existing, After, Fold_Names => Rules.Fold_Names));

   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      Rules     : Name_Rules)
      return Resolved_Action_Vectors.Vector is
     (Resolve (Items, Policy, Overrides, Existing, Fold_Names => Rules.Fold_Names, Name_Limit => Rules.Name_Limit));

end Files.Paste;
