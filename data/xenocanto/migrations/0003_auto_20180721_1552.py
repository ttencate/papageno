# Generated by Django 2.0.7 on 2018-07-21 13:52

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('xenocanto', '0002_auto_20180721_1546'),
    ]

    operations = [
        migrations.AlterField(
            model_name='recording',
            name='bitrate_bps',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='channels',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='cnt',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='date',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='elevation_m',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='en',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='file',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='gen',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='lat',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='length_s',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='lic',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='lng',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='loc',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='number_of_notes',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='pitch',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='q',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='rec',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='sampling_rate_hz',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='sonogram_url',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='sound_length',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='sp',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='speed',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='ssp',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='time',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='type',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='url',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='variable',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='recording',
            name='volume',
            field=models.TextField(blank=True, null=True),
        ),
    ]
