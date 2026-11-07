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
  fun testExportStorageNeedsTwiceTheDataInArchiveFolder() = withTempDir { exportDir ->
    withTempDir { archiveDir ->
      val usable = archiveDir.toFile().usableSpace
      val dataBytes = usable / 4 * 3

      val (required, available) = exportStorageShortfall(exportDir.toFile(), archiveDir.toFile(), dataBytes)!!

      assertEquals(2 * dataBytes, required)
      assertTrue(available < required)
      assertNull(exportStorageShortfall(exportDir.toFile(), archiveDir.toFile(), usable / 4))
    }
  }
}
