separate (Files.Operations)
function Generate_Selected_Thumbnails
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items      : constant Files.Items.Item_Vectors.Vector := Files.Model.Selection.Selected_Items (Model);
   First_Path : Unbounded_String;
   First_Name : Unbounded_String;
   Unsupported_Key  : Unbounded_String;
   Unsupported_Path : Unbounded_String;

   function Cache_Directory return String is
   begin
      return Files.File_System.Thumbnails.Default_Thumbnail_Cache_Directory (Files.Model.Current_Path (Model));
   end Cache_Directory;
begin
   declare
      Refusal : constant Operation_Result := Real_Selection_Refusal (Model);
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;

   for Item of Items loop
      declare
         Thumbnail : constant Files.File_System.Thumbnails.Thumbnail_Result :=
           Files.File_System.Thumbnails.Generate_Thumbnail (To_String (Item.Full_Path), Cache_Directory);
      begin
         if Thumbnail.Status = Files.File_System.Thumbnails.Thumbnail_Unsupported then
            --  A folder or non-image in a mixed selection is not a failure;
            --  stopping here skipped every image after it.
            Unsupported_Key := Thumbnail.Error_Key;
            Unsupported_Path := Item.Full_Path;
         elsif Thumbnail.Status /= Files.File_System.Thumbnails.Thumbnail_Generated then
            --  Refresh so thumbnails already generated for earlier items in
            --  the batch are shown, then restore the failure diagnostic.
            Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, To_String (Thumbnail.Error_Key));
            end;
            return Make_Result
              (Operation_Failed, To_String (Thumbnail.Error_Key), To_String (Item.Full_Path));
         elsif Length (First_Path) = 0 then
            First_Path := Thumbnail.Thumbnail_Path;
            First_Name := Item.Name;
         end if;
      end;
   end loop;

   if Length (First_Path) = 0 and then Length (Unsupported_Key) > 0 then
      --  Nothing in the selection could have a thumbnail.
      Files.Model.Set_Error (Model, To_String (Unsupported_Key));
      return Make_Result (Operation_Failed, To_String (Unsupported_Key), To_String (Unsupported_Path));
   end if;

   Files.Model.Set_Error (Model, "");
   declare
      Reload : constant Operation_Result :=
        Reload_Current_Directory (Model, Settings, Select_Name => To_String (First_Name));
      pragma Unreferenced (Reload);
   begin
      null;
   end;
   return Make_Result (Operation_Success, Path => To_String (First_Path));
end Generate_Selected_Thumbnails;
