# Generated by Django 2.0.7 on 2018-08-06 12:54

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('xenocanto', '0006_auto_20180722_2113'),
    ]

    operations = [
        migrations.CreateModel(
            name='AudioFile',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('file_name', models.TextField()),
                ('recording', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='audio_file', to='xenocanto.Recording')),
            ],
        ),
        migrations.CreateModel(
            name='AudioFileAnalysis',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('clarity', models.FloatField(blank=True, null=True)),
                ('audio_file', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='analysis', to='xenocanto.AudioFile')),
            ],
        ),
        migrations.AlterField(
            model_name='speciesaltname',
            name='species',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='alt_names', to='xenocanto.Species'),
        ),
        migrations.AlterField(
            model_name='speciesnametranslation',
            name='species',
            field=models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='name_translations', to='xenocanto.Species'),
        ),
    ]
