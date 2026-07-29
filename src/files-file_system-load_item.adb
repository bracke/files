separate (Files.File_System)
   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
   is
      Empty : Directory_Item;
   begin
      if Full_Path = "" or else not Ada.Directories.Exists (Full_Path) then
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.missing"));
      end if;

      declare
         Full   : constant String := Ada.Directories.Full_Name (Full_Path);
         Name   : constant String := Ada.Directories.Simple_Name (Full);
         Parent : constant String := Ada.Directories.Containing_Directory (Full);
         Kind   : Files.Types.Item_Kind;
      begin
         if Hostkit.Fs.Is_Link (Full) then
            Kind := Files.Types.Symlink_Item;
         else
            case Ada.Directories.Kind (Full) is
               when Ada.Directories.Directory =>
                  Kind := Files.Types.Directory_Item;
               when Ada.Directories.Ordinary_File =>
                  if Hostkit.Fs.Is_Executable (Full) then
                     Kind := Files.Types.Executable_Item;
                  else
                     Kind := Files.Types.Regular_File_Item;
                  end if;
               when Ada.Directories.Special_File =>
                  Kind := Files.Types.Other_Item;
            end case;
         end if;

         return
           (Success   => True,
            Item      => Item_For_Path (Full, Name, Parent, Kind, Settings),
            Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.inaccessible"));
   end Load_Item;
