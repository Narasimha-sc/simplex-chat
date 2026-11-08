package chat.simplex.app

import chat.simplex.common.views.database.exportStorageShortfall
import chat.simplex.common.views.helpers.exceedsXftpUploadLimit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class MigrationExportChecksTest {
  @Test
  fun testMigrationRefusesDataOverCoreUploadLimit() {
    val coreHardLimit = 5L * 1024 * 1024 * 1024

    assertFalse(exceedsXftpUploadLimit(coreHardLimit))
    assertTrue(exceedsXftpUploadLimit(coreHardLimit + 1))
  }

  @Test
  fun testExportStorageNeedsTwiceTheDataInArchiveFolderAndTheDataInExportFolder() {
    val dataBytes = 100L

    assertEquals(200L to 199L, exportStorageShortfall(exportFreeBytes = 100, archiveFreeBytes = 199, dataBytes))
    assertEquals(100L to 99L, exportStorageShortfall(exportFreeBytes = 99, archiveFreeBytes = 200, dataBytes))
    assertNull(exportStorageShortfall(exportFreeBytes = 100, archiveFreeBytes = 200, dataBytes))
  }
}
