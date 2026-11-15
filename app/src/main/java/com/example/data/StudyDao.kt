package com.example.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface StudyDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: StudySession): Long

    @Query("SELECT * FROM study_sessions WHERE startTimeMillis >= :startOfDay AND startTimeMillis < :endOfDay ORDER BY startTimeMillis DESC")
    fun getSessionsForDay(startOfDay: Long, endOfDay: Long): Flow<List<StudySession>>

    @Query("SELECT SUM(durationSeconds) FROM study_sessions WHERE startTimeMillis >= :startOfDay AND startTimeMillis < :endOfDay")
    fun getTodayTotalSeconds(startOfDay: Long, endOfDay: Long): Flow<Long?>

    @Query("SELECT COUNT(*) FROM study_sessions WHERE startTimeMillis >= :startOfDay AND startTimeMillis < :endOfDay")
    fun getTodaySessionCount(startOfDay: Long, endOfDay: Long): Flow<Int>

    @Query("SELECT * FROM study_sessions ORDER BY startTimeMillis DESC")
    fun getAllSessions(): Flow<List<StudySession>>

    @Delete
    suspend fun deleteSession(session: StudySession)

    @Query("DELETE FROM study_sessions")
    suspend fun clearAll()
}
