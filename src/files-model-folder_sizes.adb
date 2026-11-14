with Files.Model.Support;

package body Files.Model.Folder_Sizes is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Update_Folder_Scan
     (Model  : in out Window_Model;
      Change : not null access procedure (Scan : in out Files.Folder_Size.Session)) is
   begin
      Change (Model.Folder_Scan);
   end Update_Folder_Scan;

   procedure Note_Folder_Sizes
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector)
   is
      Ignored : Files.Folder_Size.Measurement_Vectors.Vector;
   begin
      Note_Folder_Sizes (Model, Measured, Ignored);
   end Note_Folder_Sizes;

   procedure Note_Folder_Sizes
     (Model    : in out Window_Model;
      Measured : Files.Folder_Size.Measurement_Vectors.Vector;
      Stale    : out Files.Folder_Size.Measurement_Vectors.Vector)
   is
      use type Files.Types.Item_Kind;
      package Time_Maps is new Ada.Containers.Ordered_Maps
        (Key_Type => UString, Element_Type => Ada.Calendar.Time, "<" => Ada.Strings.Unbounded."<",
         "=" => Ada.Calendar."=");
      --  Each selected directory, and when it was listed as it is now.
      Selected : Time_Maps.Map;
   begin
      Stale.Clear;
      if Measured.Is_Empty then
         return;
      end if;
      for Index of Model.Selected_Item_Indexes loop
         if Index in Model.Items.First_Index .. Model.Items.Last_Index
           and then Model.Items (Index).Kind = Files.Types.Directory_Item
         then
            Selected.Include (Model.Items (Index).Full_Path, Model.Items (Index).Modified_Time);
         end if;
      end loop;
      for Done of Measured loop
         if not Selected.Contains (Done.Path) then
            null;
         elsif Ada.Calendar."=" (Done.Listed, Files.Types.Unknown_Time)
           or else Ada.Calendar."=" (Done.Listed, Selected.Element (Done.Path))
         then
            Model.Folder_Sizes.Include (Done.Path, Done.Result);
         else
            --  Measured as the folder was before it changed: dropped, and
            --  handed back to be measured again as it is now.
            Stale.Append
              (Files.Folder_Size.Measurement'
                 (Path => Done.Path, Result => Done.Result, Listed => Selected.Element (Done.Path)));
         end if;
      end loop;
      Support.Touch_Header (Model);
   end Note_Folder_Sizes;

   procedure Clear_Folder_Size
     (Model : in out Window_Model)
     renames Files.Model.Support.Clear_Folder_Size;

   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model) is
      use type Files.Types.Item_Kind;
      Kept : Folder_Size_Maps.Map;
   begin
      --  Rebuild the cache keeping only entries for directories still selected.
      for Index of Model.Selected_Item_Indexes loop
         if Index in Model.Items.First_Index .. Model.Items.Last_Index then
            declare
               Item : Files.Items.Directory_Item renames Model.Items (Index);
            begin
               if Item.Kind = Files.Types.Directory_Item
                 and then Model.Folder_Sizes.Contains (Item.Full_Path)
               then
                  Kept.Include (Item.Full_Path, Model.Folder_Sizes.Element (Item.Full_Path));
               end if;
            end;
         end if;
      end loop;
      if not Folder_Size_Maps."=" (Model.Folder_Sizes, Kept) then
         Touch_Header (Model);
         Model.Folder_Sizes := Kept;
      end if;
   end Prune_Folder_Sizes_To_Selection;

   function Folder_Size_Cached_For
     (Model : Window_Model;
      Path  : String)
      return Boolean is
   begin
      return Model.Folder_Sizes.Contains (To_Unbounded_String (Path));
   end Folder_Size_Cached_For;

   function Folder_Size_Value
     (Model : Window_Model;
      Path  : String)
      return Files.File_System.Directory_Size_Result is
      Key : constant UString := To_Unbounded_String (Path);
   begin
      if Model.Folder_Sizes.Contains (Key) then
         return Model.Folder_Sizes.Element (Key);
      else
         return (others => <>);
      end if;
   end Folder_Size_Value;

end Files.Model.Folder_Sizes;
