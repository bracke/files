--  Test seam of Files.IO.Fs_Primitives: a lookup the host refuses.
package Files.IO.Fs_Primitives.Testing is

   --  From now on, the host refuses to say whether Path exists (compared with
   --  '\' read as '/'): Exists and Entry_Exists answer False, Entry_Is_Absent
   --  cannot tell. A removal still reaches it, as once a transient refusal
   --  has passed. Disarm with Stop_Refusing_Lookups.
   --
   --  @param Path The path whose lookups are refused.
   procedure Refuse_Lookups (Path : String);

   --  Stop refusing lookups (Refuse_Lookups).
   procedure Stop_Refusing_Lookups;

end Files.IO.Fs_Primitives.Testing;
