separate (Files.Rendering.Build_Frame_Commands)
   function Icon_Color (Kind : Files.Types.Item_Kind) return Render_Color is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return Icon_Folder_Color;
         when Files.Types.Executable_Item =>
            return Icon_Program_Color;
         when Files.Types.Regular_File_Item | Files.Types.Symlink_Item | Files.Types.Other_Item =>
            return Icon_Document_Color;
         when Files.Types.Unknown_Item =>
            return Icon_Generic_Color;
      end case;
   end Icon_Color;
