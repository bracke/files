with Ada.Strings.Unbounded;

package body Files.Folder_Size.Testing is

   function Target (Scan : Session) return String is (Ada.Strings.Unbounded.To_String (Scan.Target_Path));

end Files.Folder_Size.Testing;
