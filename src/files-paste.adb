with Ada.Strings.Unbounded;

package body Files.Paste is

   use Ada.Strings.Unbounded;

   function Desired_Path
     (Dir  : String;
      Name : String)
      return String is
   begin
      if Dir = "" then
         return Name;
      elsif Dir (Dir'Last) = '/' then
         return Dir & Name;
      else
         return Dir & "/" & Name;
      end if;
   end Desired_Path;

   --  Whether Path is present in a vector of full paths.
   function Contains
     (Paths : Files.Types.String_Vectors.Vector;
      Path  : String)
      return Boolean is
   begin
      for Existing of Paths loop
         if To_String (Existing) = Path then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Has_Conflict
     (Item     : Work_Item;
      Existing : Files.Types.String_Vectors.Vector)
      return Boolean is
   begin
      return Contains
        (Existing, Desired_Path (To_String (Item.Dest_Dir), To_String (Item.Dest_Name)));
   end Has_Conflict;

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
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         if Index > After
           and then Has_Conflict (Items.Element (Index), Existing)
           and then Effective_Decision (Policy, Override_At (Overrides, Index)) = Decision_Pending
         then
            return Index;
         end if;
      end loop;
      return 0;
   end Next_Unresolved_Conflict;

   --  One-based position of the last '.' that starts an extension (not a leading
   --  dot), or 0 when the name has no extension.
   function Extension_Start (Name : String) return Natural is
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' and then Index > Name'First then
            return Index;
         end if;
      end loop;
      return 0;
   end Extension_Start;

   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   --  A destination path derived from Desired that collides with neither
   --  Existing nor Claimed, formed by inserting " N" before the extension. This
   --  mirrors Files.File_System.Plan_Drop_Import's Available_Destination so
   --  renamed pastes match drag-and-drop's numbering.
   function Unique_Path
     (Dir      : String;
      Name     : String;
      Existing : Files.Types.String_Vectors.Vector;
      Claimed  : Files.Types.String_Vectors.Vector)
      return String
   is
      Dot       : constant Natural := Extension_Start (Name);
      Stem      : constant String :=
        (if Dot = 0 then Name else Name (Name'First .. Dot - 1));
      Extension : constant String :=
        (if Dot = 0 then "" else Name (Dot .. Name'Last));
      Counter   : Positive := 2;
      Candidate : Unbounded_String := To_Unbounded_String (Desired_Path (Dir, Name));
   begin
      while Contains (Existing, To_String (Candidate))
        or else Contains (Claimed, To_String (Candidate))
      loop
         Candidate :=
           To_Unbounded_String
             (Desired_Path (Dir, Stem & " " & Image_No_Space (Counter) & Extension));
         exit when Counter = Positive'Last;
         Counter := Counter + 1;
      end loop;
      return To_String (Candidate);
   end Unique_Path;

   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector)
      return Resolved_Action_Vectors.Vector
   is
      Actions : Resolved_Action_Vectors.Vector;
      --  Destinations already assigned earlier in this batch; a second item that
      --  would resolve to the same path is uniquified so it cannot clobber the
      --  first even before either is written to disk.
      Claimed : Files.Types.String_Vectors.Vector;

      procedure Emit_Write (Source : Files.Types.UString; Dest : String; Replaced : Boolean) is
      begin
         Actions.Append
           (Resolved_Action'
              (Source_Path => Source,
               Dest_Path   => To_Unbounded_String (Dest),
               Skip        => False,
               Replaced    => Replaced));
         Claimed.Append (To_Unbounded_String (Dest));
      end Emit_Write;
   begin
      for Index in Items.First_Index .. Items.Last_Index loop
         declare
            Item     : constant Work_Item := Items.Element (Index);
            Dir      : constant String := To_String (Item.Dest_Dir);
            Name     : constant String := To_String (Item.Dest_Name);
            Desired  : constant String := Desired_Path (Dir, Name);
            Conflict : constant Boolean := Contains (Existing, Desired);
         begin
            if not Conflict then
               --  No on-disk conflict: write to the desired name, but still
               --  uniquify against earlier same-batch claims to avoid clobber.
               if Contains (Claimed, Desired) then
                  Emit_Write (Item.Source_Path, Unique_Path (Dir, Name, Existing, Claimed), False);
               else
                  Emit_Write (Item.Source_Path, Desired, False);
               end if;
            else
               case Effective_Decision (Policy, Override_At (Overrides, Index)) is
                  when Decision_Replace =>
                     Emit_Write (Item.Source_Path, Desired, True);
                  when Decision_Rename =>
                     Emit_Write (Item.Source_Path, Unique_Path (Dir, Name, Existing, Claimed), False);
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
