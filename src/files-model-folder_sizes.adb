with Files.Model.Support;

package body Files.Model.Folder_Sizes is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Update_Scan
     (Model  : in out Window_Model;
      Change : not null access procedure (Scan : in out Files.Folder_Size.Session)) is
   begin
      Change (Model.Folder_Scan);
   end Update_Scan;

   procedure Note
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector)
   is
      Ignored : Files.Folder_Size.Measurement_Vectors.Vector;
   begin
      Note (Model, Measured, Ignored);
   end Note;

   --  Saturating sum: a total past Long_Long_Integer'Last stays there.
   --  @param Total Running total.
   --  @param Amount Bytes to add (ignored when not positive).
   procedure Add_Bytes (Total : in out Long_Long_Integer; Amount : Long_Long_Integer) is
   begin
      if Amount > 0 and then Total <= Long_Long_Integer'Last - Amount then
         Total := Total + Amount;
      elsif Amount > 0 then
         Total := Long_Long_Integer'Last;
      end if;
   end Add_Bytes;

   --  Bring Model.Selected_Folders up to the current selection and rows:
   --  one walk of the selection after it changed, none per hand-over.
   --  @param Model Model whose cache is brought up to date.
   procedure Ensure_Selected_Folders (Model : in out Window_Model) is
      use type Files.Types.Item_Kind;
      Cache : Selected_Folders_Cache renames Model.Selected_Folders;
   begin
      if Cache.Built
        and then Cache.Selection_Rev = Model.Selection_Revision_Value
        and then Cache.Rows_Rev = Model.Rows_Revision_Value
      then
         return;
      end if;
      Cache.Folders.Clear;
      Cache.Total_Bytes := 0;
      Cache.Unmeasured := 0;
      --  The selection flags, as the snapshot's walk counted: each item once.
      declare
         Selected : constant Selection_Flags := Selected_Flags (Model);
      begin
         for Index in Model.Items.First_Index .. Model.Items.Last_Index loop
            if Selected (Index) then
               declare
                  Item  : Files.Items.Directory_Item renames Model.Items (Index);
                  Found : Folder_Size_Maps.Cursor;
               begin
                  if Item.Kind = Files.Types.Directory_Item then
                     Cache.Folders.Include (Item.Full_Path, Item.Modified_Time);
                     Found := Model.Folder_Sizes.Find (Item.Full_Path);
                     if Folder_Size_Maps.Has_Element (Found) then
                        Add_Bytes (Cache.Total_Bytes, Folder_Size_Maps.Element (Found).Total_Bytes);
                     else
                        Cache.Unmeasured := Cache.Unmeasured + 1;
                     end if;
                  elsif Item.Size_Available then
                     Add_Bytes (Cache.Total_Bytes, Item.Size);
                  end if;
               end;
            end if;
         end loop;
      end;
      Cache.Built := True;
      Cache.Selection_Rev := Model.Selection_Revision_Value;
      Cache.Rows_Rev := Model.Rows_Revision_Value;
      Cache.Total_Valid := Cache.Total_Bytes < Long_Long_Integer'Last;
      Cache.Sizes_Revision := Model.Folder_Sizes_Revision;
   end Ensure_Selected_Folders;

   procedure Note
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      Stale    : out Files.Folder_Size.Measurement_Vectors.Vector)
   is
      Cache : Selected_Folders_Cache renames Model.Selected_Folders;
      --  Whether a measurement was taken in: only then does the header show
      --  anything new.
      Taken : Boolean := False;
      --  Whether the kept total still holds once these are taken in.
      Total_Holds : Boolean;
   begin
      Stale.Clear;
      if Measured.Is_Empty then
         return;
      end if;
      Ensure_Selected_Folders (Model);
      Total_Holds := Cache.Total_Valid and then Cache.Sizes_Revision = Model.Folder_Sizes_Revision;
      for Done of Measured loop
         declare
            Listed : constant Folder_Time_Maps.Cursor := Cache.Folders.Find (Done.Path);
         begin
            if not Folder_Time_Maps.Has_Element (Listed) then
               null;
            elsif Ada.Calendar."=" (Done.Listed, Files.Types.Unknown_Time)
              or else Ada.Calendar."=" (Done.Listed, Folder_Time_Maps.Element (Listed))
            then
               if Total_Holds then
                  declare
                     Before : constant Folder_Size_Maps.Cursor := Model.Folder_Sizes.Find (Done.Path);
                  begin
                     if Folder_Size_Maps.Has_Element (Before) then
                        --  Measured again: the old size leaves the total.
                        --  A saturated total cannot be taken apart.
                        if Cache.Total_Bytes = Long_Long_Integer'Last then
                           Total_Holds := False;
                        else
                           Cache.Total_Bytes :=
                             Cache.Total_Bytes - Folder_Size_Maps.Element (Before).Total_Bytes;
                        end if;
                     elsif Cache.Unmeasured > 0 then
                        Cache.Unmeasured := Cache.Unmeasured - 1;
                     end if;
                     Add_Bytes (Cache.Total_Bytes, Done.Result.Total_Bytes);
                     Total_Holds := Total_Holds and then Cache.Total_Bytes < Long_Long_Integer'Last;
                  end;
               end if;
               Model.Folder_Sizes.Include (Done.Path, Done.Result);
               Taken := True;
            else
               --  Measured as the folder was before it changed: dropped, and
               --  handed back to be measured again as it is now.
               Stale.Append
                 (Files.Folder_Size.Measurement'
                    (Path => Done.Path, Result => Done.Result, Listed => Folder_Time_Maps.Element (Listed)));
            end if;
         end;
      end loop;
      if Taken then
         Support.Note_Folder_Sizes (Model);
         Cache.Total_Valid := Total_Holds;
         Cache.Sizes_Revision := Model.Folder_Sizes_Revision;
      end if;
   end Note;

   procedure Clear
     (Model : in out Window_Model)
     renames Files.Model.Support.Clear_Folder_Size;

   procedure Prune_To_Selection
     (Model : in out Window_Model) is
      Cache : Selected_Folders_Cache renames Model.Selected_Folders;
      Kept  : Folder_Size_Maps.Map;
      Still : Natural := 0;
   begin
      if Model.Folder_Sizes.Is_Empty then
         return;
      end if;
      Ensure_Selected_Folders (Model);
      --  Counted first, without copying: when every measured folder is still
      --  selected (the usual case) there is nothing to drop.
      for Position in Model.Folder_Sizes.Iterate loop
         if Cache.Folders.Contains (Folder_Size_Maps.Key (Position)) then
            Still := Still + 1;
         end if;
      end loop;
      if Still = Natural (Model.Folder_Sizes.Length) then
         return;
      end if;
      for Position in Model.Folder_Sizes.Iterate loop
         if Cache.Folders.Contains (Folder_Size_Maps.Key (Position)) then
            Kept.Insert (Folder_Size_Maps.Key (Position), Folder_Size_Maps.Element (Position));
         end if;
      end loop;
      --  Only folders no longer selected leave: a kept total still holds.
      declare
         Holds : constant Boolean :=
           Cache.Total_Valid and then Cache.Sizes_Revision = Model.Folder_Sizes_Revision;
      begin
         Note_Folder_Sizes (Model);
         Model.Folder_Sizes := Kept;
         if Holds then
            Cache.Sizes_Revision := Model.Folder_Sizes_Revision;
         end if;
      end;
   end Prune_To_Selection;

   function Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean is
   begin
      return Model.Folder_Sizes.Contains (To_Unbounded_String (Path));
   end Cached_For;

   function Cached_For
     (Model : Window_Model;
      Path  : Ada.Strings.Unbounded.Unbounded_String)
      return Boolean is
     (Model.Folder_Sizes.Contains (Path));

   procedure Selection_Total
     (Model   : Window_Model;
      Kept    : out Boolean;
      Bytes   : out Long_Long_Integer;
      Pending : out Boolean)
   is
      Cache : Selected_Folders_Cache renames Model.Selected_Folders;
   begin
      Kept := Cache.Built
        and then Cache.Total_Valid
        and then Cache.Selection_Rev = Model.Selection_Revision_Value
        and then Cache.Rows_Rev = Model.Rows_Revision_Value
        and then Cache.Sizes_Revision = Model.Folder_Sizes_Revision;
      Bytes := (if Kept then Cache.Total_Bytes else 0);
      Pending := Kept and then Cache.Unmeasured > 0;
   end Selection_Total;

   procedure Find
     (Model : Window_Model;
      Path  : Ada.Strings.Unbounded.Unbounded_String;
      Known : out Boolean;
      Bytes : out Long_Long_Integer)
   is
      Found : constant Folder_Size_Maps.Cursor := Model.Folder_Sizes.Find (Path);
   begin
      Known := Folder_Size_Maps.Has_Element (Found);
      Bytes := (if Known then Folder_Size_Maps.Element (Found).Total_Bytes else 0);
   end Find;

   function Revision (Model : Window_Model) return Natural is (Model.Folder_Sizes_Revision);

   function Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System_Types.Directory_Size_Result is
      Key : constant UString := To_Unbounded_String (Path);
   begin
      if Model.Folder_Sizes.Contains (Key) then
         return Model.Folder_Sizes.Element (Key);
      else
         return (others => <>);
      end if;
   end Value;

end Files.Model.Folder_Sizes;
