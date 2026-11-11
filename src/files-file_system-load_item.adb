separate (Files.File_System)
function Load_Item
  (Full_Path : String;
   Settings  : Files.Settings.Settings_Model)
   return Item_Load_Result
is
   Empty : Directory_Item;
begin
   if Full_Path = "" or else not Files.Fs_Primitives.Entry_Exists (Full_Path) then
      return
        (Success   => False,
         Item      => Empty,
         Error_Key => To_Unbounded_String ("error.path.missing"));
   end if;

   declare
      --  A link is the item, not what it points at: only its text is made
      --  absolute.
      Full   : constant String :=
        (if Hostkit.Fs.Is_Link (Full_Path) then Files.Fs_Primitives.Absolute_Name (Full_Path)
         else Files.Fs_Primitives.Full_Name (Full_Path));
      Name   : constant String := Files.Fs_Primitives.Leaf_Text (Full);
      Parent : constant String := Files.Fs_Primitives.Parent_Directory (Full);
      Kind   : constant Files.Types.Item_Kind := Kind_From_Path (Full);
   begin
      --  A root is no folder's item: it has neither a name nor a parent.
      if Name = "" or else Parent = "" then
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.inaccessible"));
      end if;

      return
        (Success   => True,
         Item      => Item_For_Path (Full, Name, Parent, Kind, Settings, (others => <>)),
         Error_Key => Null_Unbounded_String);
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
      return
        (Success   => False,
         Item      => Empty,
         Error_Key => To_Unbounded_String ("error.path.inaccessible"));
end Load_Item;
