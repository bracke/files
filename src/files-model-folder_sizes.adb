separate (Files.Model)
package body Folder_Sizes is

   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Folder_Sizes.Include (To_Unbounded_String (Path), Value);
   end Set_Folder_Size;

   procedure Clear_Folder_Size
     (Model : in out Window_Model) is
   begin
      Cancel_Folder_Scan (Model);
      if not Model.Folder_Sizes.Is_Empty then
         Model.Revision_Value := Model.Revision_Value + 1;
         Model.Folder_Sizes.Clear;
      end if;
   end Clear_Folder_Size;

   procedure Prune_Folder_Sizes_To_Selection
     (Model : in out Window_Model) is
      use type Files.Types.Item_Kind;
      Kept : Folder_Size_Maps.Map;
   begin
      --  Rebuild the cache keeping only entries for directories still selected.
      for Item of Selected_Items (Model) loop
         if Item.Kind = Files.Types.Directory_Item
           and then Model.Folder_Sizes.Contains (Item.Full_Path)
         then
            Kept.Include (Item.Full_Path, Model.Folder_Sizes.Element (Item.Full_Path));
         end if;
      end loop;
      if not Folder_Size_Maps."=" (Model.Folder_Sizes, Kept) then
         Model.Revision_Value := Model.Revision_Value + 1;
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

end Folder_Sizes;
