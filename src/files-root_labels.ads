with Files.File_System;

--  What a root location is called on screen: the root selector's rows and the
--  folder tree's top nodes say the same.
package Files.Root_Labels is

   --  A root's label in the current locale: its key's pattern with its name
   --  filled in ("Mount: usb"), its detail after it ("Mount: usb (vfat)"),
   --  or its literal label, or its path when it has none.
   --
   --  @param Root The root entry.
   --  @return The text to show.
   function Display_Label (Root : Files.File_System.Root_Entry) return String;

end Files.Root_Labels;
