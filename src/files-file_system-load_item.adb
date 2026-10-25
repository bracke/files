separate (Files.File_System)
function Load_Item
  (Full_Path : String;
   Settings  : Files.Settings.Settings_Model)
   return Item_Load_Result
is
   Empty : Directory_Item;
begin
   if Full_Path = "" or else not (Ada.Directories.Exists (Full_Path) or else Hostkit.Fs.Is_Link (Full_Path)) then
      return
        (Success   => False,
         Item      => Empty,
         Error_Key => To_Unbounded_String ("error.path.missing"));
   end if;

   declare
      Full   : constant String :=
        (if Hostkit.Fs.Is_Link (Full_Path) then
           GNAT.OS_Lib.Normalize_Pathname (Full_Path, Resolve_Links => False)
         else Ada.Directories.Full_Name (Full_Path));
      Name   : constant String := Ada.Directories.Simple_Name (Full);
      Parent : constant String := Ada.Directories.Containing_Directory (Full);
      Kind   : constant Files.Types.Item_Kind := Kind_From_Path (Full);
   begin

      return
        (Success   => True,
         Item      => Item_For_Path (Full, Name, Parent, Kind, Settings, (others => <>)),
         Error_Key => Null_Unbounded_String);
   end;
exception
   when others =>
      return
        (Success   => False,
         Item      => Empty,
         Error_Key => To_Unbounded_String ("error.path.inaccessible"));
end Load_Item;
